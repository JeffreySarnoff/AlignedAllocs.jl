module AlignedAllocs

export memalign, memalign_clear, alignment

using Base: Libc
using PrecompileTools

# define CACHE_LINE_SIZE as a module scoped constant
include("precompilation.jl")

if !(@isdefined CACHE_LINE_SIZE)
   if @isdefined detect_cache_line_size
       const CACHE_LINE_SIZE = detect_cache_line_size()
   else
       const CACHE_LINE_SIZE = FallbackCacheLineSize
   end
end

# allocation error codes
const ENOMEM = Cint(12)  # Out of memory error code
const EINVAL = Cint(22)  # Invalid argument error code

"""
    memalign(::Type{T}, nitems::Integer, align::Integer=64) where T

__aligned uninitialized memory allocation__

Allocate memory for a densevector vec = Vector{T}(undef, nitems)
- vec starts at a memory address that is a multiple of `align` bytes
- Int(pointer(vec)) % align == 0

- align constrains the memory address of start of the vector 
- align is bitcount, (align * 8 is the alignment in bits)
- align must be a power of 2 and must be >= 16

`memalign` works on Unixes (Linux, Apple, Bsd), Windows
""" memalign

@inline function memalign(::Type{T}, nitems::Integer, align::Integer=CACHE_LINE_SIZE) where T
    @static Sys.iswindows() ? memalign_windows(T, nitems, align) : memalign_posix(T, nitems, align)
end

"""
    memalign_clear(::Type{T}, nitems::Integer, align=64) where T

__aligned zeroed memory allocation__

Allocate memory for a densevector vec = zeros(T, nitems)
- vec starts at a memory address that is a multiple of align bytes

`memalign_clear` works on Unixes (Linux, Apple, Bsd), Windows
""" memalign_clear

@inline function memalign_clear(::Type{T}, nitems::Integer, align::Integer=CACHE_LINE_SIZE) where T
    @static Sys.iswindows() ? memalign_clear_windows(T, nitems, align) : 
                              memalign_clear_posix(T, nitems, align)
end

@inline function memalign_clear_windows(::Type{T}, nitems::Integer, align::Integer) where T
    vec = memalign_windows(T, nitems, align)
    fill!(vec, zero(T))
    vec
end
        
@inline function memalign_clear_posix(::Type{T}, nitems::Integer, align::Integer) where T
    vec = memalign_posix(T, nitems, align)
    fill!(vec, zero(T))
    vec
end

# =================================================================================

function memalign_posix(::Type{T}, nitems::Integer, align::Integer) where T
    check_args(T, nitems, align)

    total_bytes = Base.checked_mul(nitems, sizeof(T))

    local ptr::Ptr{T} = Ptr{T}()
    memref = Ref{Ptr{Cvoid}}(C_NULL)
    ret = ccall((:posix_memalign), Cint,
                (Ref{Ptr{Cvoid}}, Csize_t, Csize_t),
                 memref, align, total_bytes)
    !iszero(ret) && alloc_error(ret)
    
    ptr = memref[]
    confirm_alignment(ptr, align) 
    
    # use the allocated memory as a Vector{T}(undef, nitems)
    vec = @GC.preserve ptr unsafe_wrap(Array, Ptr{T}(ptr), nitems; own=true)
    
    return vec
end

function memalign_windows(::Type{T}, nitems::Integer, align::Integer) where T
    check_args(T, nitems, align)
    
    total_bytes = Base.checked_mul(nitems, sizeof(T))
        
    local ptr::Ptr{T} = Ptr{T}()    
    ptr = ccall((:_aligned_malloc, "msvcrt"), Ptr{T},
                (Csize_t, Csize_t), total_bytes, align)        
    (ptr == C_NULL) && alloc_error(ENOMEM)

    confirm_alignment(ptr, align) 
    
    # use the allocated memory as a Vector{T}(undef, nitems)
    vec = @GC.preserve ptr unsafe_wrap(Array, Ptr{T}(ptr), nitems; own=false)
    
    # allow the GC to free the allocated memory
    @static if VERSION > v"1.11-"
        finalizer(getfield(vec, :ref).mem) do m
            @GC.preserve ptr ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{T},), pointer(m))
        end
    else
        finalizer(vec) do v
            @GC.preserve ptr ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{T},), pointer(v))
        end
    end    

    return vec
end

# =================================================================================

# error handling

function check_args(::Type{T}, nitems, align) where T
    isbitstype(T) || 
    throw(ArgumentError("element_type ($T) must be a `bitstype`"))

    nitems > 0 || 
    throw(ArgumentError("element_count ($nitems) must be > 0"))

    (ispow2(align) && align >= 16) || 
    throw(ArgumentError("Alignment ($align) must be 2^p where p >= 4"))
end

function confirm_alignment(ptr::Ptr, align::Integer)
    if UInt(ptr) % align != 0
        if Sys.iswindows()
            ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{Cvoid},), ptr)
        else
            ccall((:free, "Libc"), Cvoid, (Ptr{Cvoid},), ptr)
        end

        errmsg = "aligned memory allocation failed: returned address $(UInt(ptr)) is not aligned to $(align) bytes"
        throw(ErrorException(errmsg))
    end
end

function alloc_error(err)
    iszero(err) && return nothing
    
    if err == EINVAL
        throw(ArgumentError("Invalid alignment: must be power of 2 and multiple of $ptr_size"))
    elseif err == ENOMEM
        throw(OutOfMemoryError())
    else
        throw(ErrorException("Allocation error: $err"))
    end
end

# alignment checking

alignment(xs::AbstractArray) = 2^trailing_zeros(UInt64(pointer(xs)))
    
end  # AlignedAllocs


