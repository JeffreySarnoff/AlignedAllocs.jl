module AlignedAllocs

#=

• I’m summarizing changes including memalign* returning zero-copy Base.Memory using unsafe_wrap around lines 82 and 96,
  updated docstrings from lines 23 to 47, and the Windows finalizer hooking _aligned_free via Base.unsafe_convert at
  lines 98-101. The allocate error message improvements are around lines 134-139. I’ll mention verifying the memalign
  behavior with a julia command that prints the buffer type and pointer, showing it’s Memory{Float64}, and note the
  finalizer triggers cleanly on exit. I’ll also suggest next steps like testing memalign_clear and running the package
  tests to confirm everything works smoothly.

> - Swapped both allocation paths to wrap the aligned pointer in Base.Memory{T} so we expose GenericMemory buffers
  without copies and still honor caller-specified alignment (src/AlignedAllocs.jl:35-104).
  - Updated docs and clear helpers to reflect the new return type and zero-fill behaviour, keeping the API surface
  consistent (src/AlignedAllocs.jl:23-64).
  - Retained explicit freeing on Windows by attaching a finalizer that calls _aligned_free via Base.unsafe_convert, and
  clarified the alignment error message (src/AlignedAllocs.jl:98-139).

=#

export memalign, memalign_clear, alignment

using Base: Libc, Memory
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
    memalign(::Type{T}, nitems::Integer, align::Integer=CACHE_LINE_SIZE) where T

__aligned uninitialized memory allocation__

Allocate aligned storage as `Memory{T}(undef, nitems)` without copying.
- The returned buffer starts at an address that is a multiple of `align` bytes.
- `align` must be a power of 2 and at least 16.

`memalign` works on Unixes (Linux, Apple, BSD) and Windows.
""" memalign

@inline function memalign(::Type{T}, nitems::Integer, align::Integer=CACHE_LINE_SIZE) where T
    @static Sys.iswindows() ? memalign_windows(T, nitems, align) : memalign_posix(T, nitems, align)
end

"""
    memalign_clear(::Type{T}, nitems::Integer, align::Integer=CACHE_LINE_SIZE) where T

__aligned zeroed memory allocation__

Allocate aligned storage as `Memory{T}(undef, nitems)` and fill it with zeros.

`memalign_clear` works on Unixes (Linux, Apple, BSD) and Windows.
""" memalign_clear

@inline function memalign_clear(::Type{T}, nitems::Integer, align::Integer=CACHE_LINE_SIZE) where T
    @static Sys.iswindows() ? memalign_clear_windows(T, nitems, align) :
                              memalign_clear_posix(T, nitems, align)
end

@inline function memalign_clear_windows(::Type{T}, nitems::Integer, align::Integer) where T
    buf = memalign_windows(T, nitems, align)
    fill!(buf, zero(T))
    buf
end
        
@inline function memalign_clear_posix(::Type{T}, nitems::Integer, align::Integer) where T
    buf = memalign_posix(T, nitems, align)
    fill!(buf, zero(T))
    buf
end

# =================================================================================

function memalign_posix(::Type{T}, nitems::Integer, align::Integer) where T
    check_args(T, nitems, align)

    total_bytes = Base.checked_mul(nitems, sizeof(T))

    memref = Ref{Ptr{Cvoid}}(C_NULL)
    ret = ccall((:posix_memalign), Cint,
                (Ref{Ptr{Cvoid}}, Csize_t, Csize_t),
                 memref, align, total_bytes)
    !iszero(ret) && alloc_error(ret)
    
    ptr = memref[]
    confirm_alignment(ptr, align)

    return @GC.preserve ptr unsafe_wrap(Memory{T}, Ptr{T}(ptr), nitems; own=true)
end

function memalign_windows(::Type{T}, nitems::Integer, align::Integer) where T
    check_args(T, nitems, align)
    
    total_bytes = Base.checked_mul(nitems, sizeof(T))
        
    ptr = ccall((:_aligned_malloc, "msvcrt"), Ptr{T},
                (Csize_t, Csize_t), total_bytes, align)
    (ptr == C_NULL) && alloc_error(ENOMEM)

    confirm_alignment(ptr, align)
    
    buf = @GC.preserve ptr unsafe_wrap(Memory{T}, Ptr{T}(ptr), nitems; own=false)

    finalizer(buf) do mem
        p = Base.unsafe_convert(Ptr{Cvoid}, mem)
        p != C_NULL && ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{Cvoid},), p)
    end

    return buf
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
        throw(ArgumentError("Invalid alignment: must be power of 2 and a multiple of sizeof(Ptr{Cvoid})"))
    elseif err == ENOMEM
        throw(OutOfMemoryError())
    else
        throw(ErrorException("Allocation error: $err"))
    end
end

# alignment checking

alignment(xs::AbstractArray) = 2^trailing_zeros(UInt64(pointer(xs)))
    
end  # AlignedAllocs
