module AlignedAllocs

# ============ SECTION 1: Package Dependencies ============
using Base: Libc
using PrecompileTools

# ============ SECTION 2: Exports ============
export memalign, memalign_clear, memalign_fixed, memalign_clear_fixed, memalign_vectors,
       memaligned, memaligned_clear, alignment, FixedAlignedAllocs

# ============ SECTION 3: Include Core Dependencies ============
include("precompilation.jl")

# ============ SECTION 4: Constants (Type-Stable) ============
const CACHE_LINE_SIZE::Int = let
    if @isdefined detect_cache_line_size
        detect_cache_line_size()::Int
    else
        FallbackCacheLineSize::Int
    end
end

const ENOMEM::Cint = Cint(12)
const EINVAL::Cint = Cint(22)

# ============ SECTION 5: Type-Stable Helper Functions ============

"""
Normalize dimensions to Int tuple with validation.
Type-stable: always returns NTuple{N,Int}.
"""
@inline function _normalize_dims(dims::Tuple{Vararg{Integer,N}}) where {N}
    N == 0 && throw(ArgumentError("at least one dimension is required"))
    # Use ntuple with Val for compile-time optimization
    ntuple(Val(N)) do i
        @inbounds begin  # Safe after N check
            dim = Int(dims[i])
            dim > 0 || throw(ArgumentError("dimension $i ($dim) must be > 0"))
            dim
        end
    end::NTuple{N,Int}
end

"""
Compute total length with overflow checking.
Type-stable: always returns Int.
"""
@inline function _checked_length(dims::NTuple{N,Int}) where {N}
    len = one(Int)  # Type-stable initialization
    @inbounds for dim in dims  # Safe for NTuple
        len, overflow = Base.Checked.mul_with_overflow(len, dim)
        overflow && throw(OverflowError("dimension product overflowed Int"))
    end
    return len::Int
end

"""
Reshape with type preservation.
"""
@inline function _reshape_aligned(flat::Vector{T}, dims::NTuple{N,Int}) where {T,N}
    # reshape is already type-stable for these inputs
    reshape(flat, dims)
end

"""
Generic aligned allocation constructor with function barrier.
"""
@inline function _aligned_construct(::Type{T}, dims::Tuple{Vararg{Integer,N}}, 
                                   align::Integer, allocator::F, builder::G) where {T,N,F,G}
    # Function barrier: separate validation from allocation
    sdims = _normalize_dims(dims)
    len = _checked_length(sdims)
    
    # Type-stable allocation
    buffer = allocator(T, len; align=Int(align))
    return builder(buffer, sdims)
end

"""
Compute byte count with overflow checking.
Generated function for optimal performance.
"""
@generated function _nbytes(::Type{T}, n::Integer) where {T}
    sz = sizeof(T)
    if sz == 1
        return :(Int(n))
    elseif sz == 2
        return :(Int(n) << 1)
    elseif sz == 4
        return :(Int(n) << 2)
    elseif sz == 8
        return :(Int(n) << 3)
    else
        return :(Base.checked_mul(Int(n), $sz))
    end
end

# ============ SECTION 6: Main API Functions ============

"""
    memalign(::Type{T}, nitems::Integer; align::Integer=CACHE_LINE_SIZE) where T

Allocate aligned storage for `nitems` elements of type `T` and return a `Vector{T}` 
whose data pointer is aligned to `align` bytes. `align` must be a power of two at least 16.

Performance: Uses platform-specific aligned allocation for optimal memory access.
"""
@inline function memalign(::Type{T}, nitems::Integer; align::Integer=CACHE_LINE_SIZE) where T
    @static if Sys.iswindows()
        memalign_windows(T, nitems, align)
    else
        memalign_posix(T, nitems, align)
    end
end

"""
    memalign_clear(::Type{T}, nitems::Integer; align::Integer=CACHE_LINE_SIZE) where T

Allocate aligned storage for `nitems` elements of type `T`, zero-initialize it, 
and return a `Vector{T}`.

Performance: Combines allocation and zeroing for better cache utilization.
"""
@inline function memalign_clear(::Type{T}, nitems::Integer; align::Integer=CACHE_LINE_SIZE) where T
    vect = memalign(T, nitems; align=align)
    
    # Optimize zeroing based on size
    nbytes = _nbytes(T, nitems)
    
    if nbytes < 256
        # Small arrays: direct zeroing
        @inbounds for i in eachindex(vect)
            vect[i] = zero(T)
        end
    else
        # Large arrays: memset is faster
        GC.@preserve vect begin
            ptr = Base.unsafe_convert(Ptr{UInt8}, pointer(vect))
            zeromem(ptr, nbytes)
        end
    end
    
    return vect
end

"""
    memaligned(::Type{T}, dims...; align=CACHE_LINE_SIZE) where T

Allocate aligned storage for a multi-dimensional array with element type `T`.
Returns reshaped view of underlying aligned vector.
"""
@inline function memaligned(::Type{T}, dims::Vararg{Integer,N}; 
                           align::Integer=CACHE_LINE_SIZE) where {T,N}
    _aligned_construct(T, dims, align, memalign, _reshape_aligned)
end

@inline function memaligned(::Type{T}, dims::Tuple{Vararg{Integer,N}}; 
                           align::Integer=CACHE_LINE_SIZE) where {T,N}
    _aligned_construct(T, dims, align, memalign, _reshape_aligned)
end

"""
    memaligned_clear(::Type{T}, dims...; align=CACHE_LINE_SIZE) where T

Allocate aligned storage for a multi-dimensional array and zero-initialize.
"""
@inline function memaligned_clear(::Type{T}, dims::Vararg{Integer,N}; 
                                 align::Integer=CACHE_LINE_SIZE) where {T,N}
    _aligned_construct(T, dims, align, memalign_clear, _reshape_aligned)
end

@inline function memaligned_clear(::Type{T}, dims::Tuple{Vararg{Integer,N}}; 
                                 align::Integer=CACHE_LINE_SIZE) where {T,N}
    _aligned_construct(T, dims, align, memalign_clear, _reshape_aligned)
end

# ============ SECTION 7: Platform-Specific Implementations ============

"""
POSIX-compliant aligned allocation.
"""
@inline function memalign_posix(::Type{T}, nitems::Integer, align::Integer) where T
    check_args(T, nitems, align)
    
    nbytes = _nbytes(T, nitems)
    rawptr = Ref{Ptr{Cvoid}}(C_NULL)
    
    ret = ccall(:posix_memalign, Cint,
                (Ref{Ptr{Cvoid}}, Csize_t, Csize_t),
                rawptr, Csize_t(align), Csize_t(nbytes))
    
    ret == 0 || alloc_error(ret)
    
    ptr = Ptr{T}(rawptr[])
    confirm_alignment(ptr, align)
    
    # Use GC.@preserve for safety
    vect = GC.@preserve unsafe_wrap(Vector{T}, ptr, Int(nitems); own=true)
    return vect
end

"""
Windows-specific aligned allocation with custom finalizer.
"""
@inline function memalign_windows(::Type{T}, nitems::Integer, align::Integer) where T
    check_args(T, nitems, align)
    
    nbytes = _nbytes(T, nitems)
    ptr = ccall((:_aligned_malloc, "msvcrt"), Ptr{T},
                (Csize_t, Csize_t), Csize_t(nbytes), Csize_t(align))
    
    ptr == C_NULL && alloc_error(ENOMEM)
    confirm_alignment(ptr, align)
    
    # Create vector with custom finalizer
    vect = unsafe_wrap(Vector{T}, ptr, Int(nitems); own=false)
    
    # Use mutable struct for finalizer state (more efficient than Ref)
    finalizer(vect) do v
        # Ensure single free
        if pointer(v) != C_NULL
            ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{Cvoid},), pointer(v))
        end
    end
    
    return vect
end

# ============ SECTION 8: Validation Functions ============

"""
Validate allocation arguments.
Type-stable with @inline for constant propagation.
"""
@inline function check_args(::Type{T}, nitems::Integer, align::Integer) where T
    isbitstype(T) || throw(ArgumentError("element_type ($T) must be a `bitstype`"))
    nitems > 0 || throw(ArgumentError("element_count ($nitems) must be > 0"))
    is_alignment_valid(align) || throw(ArgumentError("Alignment ($align) must be 2^p where p >= 4"))
    return nothing
end

"""
Zero memory using optimized memset.
"""
@inline function zeromem(ptr::Ptr{UInt8}, nbytes::Int)
    Base.memset(ptr, 0x00, nbytes)
    return nothing
end

"""
Check if alignment is valid (power of 2, >= 16).
Branchless implementation for better performance.
"""
@inline is_alignment_valid(align::Integer) = 
    (align >= 16) & (((align - 1) & align) == 0)

"""
Verify pointer alignment and cleanup on failure.
"""
@inline function confirm_alignment(ptr::Ptr, align::Integer)
    mask = UInt(align - 1)
    if (UInt(ptr) & mask) != 0
        # Cleanup before throwing
        @static if Sys.iswindows()
            ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{Cvoid},), ptr)
        else
            ccall(:free, Cvoid, (Ptr{Cvoid},), ptr)
        end
        throw(ErrorException(
            "aligned allocation failed: address $(UInt(ptr)) not aligned to $(align) bytes"
        ))
    end
    return nothing
end

"""
Convert allocation error codes to exceptions.
"""
@noinline function alloc_error(err::Cint)
    if err == EINVAL
        throw(ArgumentError(
            "Invalid alignment: must be power of 2 and multiple of $(Sys.WORD_SIZE >> 3)"
        ))
    elseif err == ENOMEM
        throw(OutOfMemoryError())
    else
        throw(ErrorException("Allocation error: $err"))
    end
end

"""
    alignment(xs::AbstractArray)

Return the largest power-of-two alignment that divides the data pointer of `xs`.
Empty arrays return `0` because they do not own storage.

Performance: Branchless computation using bit manipulation.
"""
@inline function alignment(xs::AbstractArray)
    addr = UInt(pointer(xs))
    # Branchless: trailing zeros gives log2 of alignment
    return addr == 0 ? 0 : Int(addr & -addr)
end

# ============ SECTION 9: Module Inclusions ============
include("FixedAlignedAllocs.jl")

# ============ SECTION 10: Module Constants ============
const FixedAlignedAllocs = (; memalign_fixed, memalign_clear_fixed, alignment)

# ============ SECTION 11: Precompilation Workload ============
@setup_workload begin
    @compile_workload begin
        # Common allocation patterns
        for T in (Float64, Float32, Int64, Int32, UInt8)
            v = memalign(T, 64)
            v = memalign_clear(T, 128)
            alignment(v)
        end
        
        # Multi-dimensional arrays
        m = memaligned(Float64, 8, 8)
        m = memaligned_clear(Float32, 16, 16)
    end
end

end  # module AlignedAllocs
