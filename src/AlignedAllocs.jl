module AlignedAllocs

export memalign_vec, memalign_clear_vec,
       memalign_fix, memalign_clear_fix, 
       memalign_seq, memalign_clear_seq, 
       alignment,
       memalign, memalign_clear # old names for memalign_vec, memalign_clear_vec

using Base: Libc
using PrecompileTools

include("precompilation.jl")

if !(@isdefined CACHE_LINE_SIZE)
    if @isdefined detect_cache_line_size
        const CACHE_LINE_SIZE = detect_cache_line_size()
    else
        const CACHE_LINE_SIZE = FallbackCacheLineSize
    end
end

const ENOMEM = Cint(12)
const EINVAL = Cint(22)

include("FixedAlignedAllocs.jl")

"""
    memalign_vec(::Type{T}, nitems::Integer, align::Integer=CACHE_LINE_SIZE) where T

Allocate aligned storage for `nitems` elements of type `T` and return a `Vector{T}` whose data pointer is aligned to `align` bytes. `align` must be a power of two at least 16.
""" memalign_vec

@inline function memalign_vec(::Type{T}, nitems::Integer; align::Integer=CACHE_LINE_SIZE) where T
    @static Sys.iswindows() ? memalign_windows(T, nitems, align) : memalign_posix(T, nitems, align)
end

@inline function memalign(::Type{T}, nitems::Integer; align::Integer=CACHE_LINE_SIZE) where T = 
                 memalign_vec(T, nitems; align)

"""
    memalign_clear_vec(::Type{T}, nitems::Integer, align::Integer=CACHE_LINE_SIZE) where T

Allocate aligned storage for `nitems` elements of type `T`, zero-initialize it, and return a `Vector{T}`.
""" memalign_clear_vec

@inline function memalign_clear_vec(::Type{T}, nitems::Integer; align::Integer=CACHE_LINE_SIZE) where T
    vect = memalign(T, nitems; align)
    Base.GC.@preserve vect begin
        nbytes = Int(_nbytes(T, nitems))
        ptr = Base.unsafe_convert(Ptr{UInt8}, Base.pointer(vect))
        zeromem(ptr, nbytes)
    end
    return vect
end

@inline function memalign_clear(::Type{T}, nitems::Integer; align::Integer=CACHE_LINE_SIZE) where T = 
                 memalign_clear_vec(T, nitems; align)

@inline function memalign_posix(::Type{T}, nitems::Integer, align::Integer) where T
    check_args(T, nitems, align)

    nbytes = Int(_nbytes(T, nitems))
    rawptr = Ref{Ptr{Cvoid}}(C_NULL)
    ret = ccall((:posix_memalign), Cint,
                (Ref{Ptr{Cvoid}}, Csize_t, Csize_t),
                rawptr, Csize_t(align), Csize_t(nbytes))
    ret == 0 || alloc_error(ret)

    ptr = Ptr{T}(rawptr[])
    confirm_alignment(ptr, align)

    vect = @GC.preserve unsafe_wrap(Vector{T}, ptr, nitems; own=true)
    return vect
end

@inline function memalign_windows(::Type{T}, nitems::Integer, align::Integer) where T
    check_args(T, nitems, align)

    nbytes = Int(_nbytes(T, nitems))
    ptr = ccall((:_aligned_malloc, "msvcrt"), Ptr{T},
                (Csize_t, Csize_t), Csize_t(nbytes), Csize_t(align))
    (ptr == C_NULL) && alloc_error(ENOMEM)

    confirm_alignment(ptr, align)

    vect = unsafe_wrap(Vector{T}, ptr, nitems; own=false)
    freed = Ref(false)
    finalizer(vect) do _
        if !freed[]
            ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{Cvoid},), Ptr{Cvoid}(ptr))
            freed[] = true
        end
    end

    return vect
end

@generated function _nbytes(::Type{T}, n::Integer) where {T}
    sz = sizeof(T)
    return :(Base.checked_mul(n, $sz))
end

@inline function check_args(::Type{T}, nitems::Integer, align::Integer) where T
    isbitstype(T) || throw(ArgumentError("element_type ($T) must be a `bitstype`"))
    nitems > 0 || throw(ArgumentError("element_count ($nitems) must be > 0"))
    is_alignment_valid(align) || throw(ArgumentError("Alignment ($align) must be 2^p where p >= 4"))
    return nothing
end

@inline function zeromem(ptr::Ptr{UInt8}, nbytes::Int)
    Base.memset(ptr, 0x00, nbytes)
    return nothing
end

@inline is_alignment_valid(align::Integer) = align >= 16 && ((align - 1) & align) == 0

@inline function confirm_alignment(ptr::Ptr, align::Integer)
    mask = UInt(align - 1)
    if (UInt(ptr) & mask) != 0
        if Sys.iswindows()
            ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{Cvoid},), ptr)
        else
            ccall((:free, "Libc"), Cvoid, (Ptr{Cvoid},), ptr)
        end
        errmsg = "aligned memory allocation failed: returned address $(UInt(ptr)) is not aligned to $(align) bytes"
        throw(ErrorException(errmsg))
    end
    return nothing
end

@inline function alloc_error(err)
    iszero(err) && return nothing

    if err == EINVAL
        throw(ArgumentError("Invalid alignment: must be power of 2 and multiple of $(Sys.WORD_SIZE >> 3)"))
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
"""
@inline function alignment(xs::AbstractArray)
    addr = UInt(pointer(xs))
    return addr == 0 ? 0 : Int(addr & -addr)
end

@inline function alignment(xs::NTuple{N,T}) where {N,T}
    minimum(map(alignment, xs))
end

end  # AlignedAllocs
