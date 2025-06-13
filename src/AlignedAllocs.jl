module AlignedAllocs

export memalign, memalign_clear, alignment

using Base: Libc

# define CACHE_LINE_SIZE as a module scoped constant

using PrecompileTools

# Top-Level Constants and (Optional) Struct Declarations
FallbackCacheLineSize = detect_cache_line_size()  # Default fallback value for cache line size.

# Linux: sysconf constant for L1 data cache line size.
const _SC_LEVEL1_DCACHE_LINESIZE = 190  # defined in <unistd.h>

# Windows: Constants for cache relationship and cache types.
const RELATION_CACHE = 2
const CACHE_TYPE_DATA = 1
const CACHE_TYPE_INSTRUCTION = 2
const CACHE_TYPE_UNIFIED = 3

# Define structure size and field offsets for Windows.
if Sys.WORD_SIZE == 64
    const ENTRY_SIZE          = 48
    const RELATIONSHIP_OFFSET = 8         # After 8 bytes of ProcessorMask.
    const UNION_OFFSET        = 16        # The union starts at offset 16.
    const CACHE_LEVEL_OFFSET  = UNION_OFFSET       # Level is at offset 16.
    const LINE_SIZE_OFFSET    = UNION_OFFSET + 2   # LineSize is at offset 18.
    const CACHE_TYPE_OFFSET   = UNION_OFFSET + 8   # Type is at offset 24.
else
    const ENTRY_SIZE          = 32
    const RELATIONSHIP_OFFSET = 4         # 4 bytes for ProcessorMask.
    const UNION_OFFSET        = 8
    const CACHE_LEVEL_OFFSET  = UNION_OFFSET       # Level is at offset 8.
    const LINE_SIZE_OFFSET    = UNION_OFFSET + 2   # LineSize is at offset 10.
    const CACHE_TYPE_OFFSET   = UNION_OFFSET + 8   # Type is at offset 16.
end

# Main function to retrieve the cache line size.
function detect_cache_line_size()::Int
    if Sys.isapple()
        # macOS: try to get "hw.cachelinesize" via sysctlbyname.
        line_size = Ref{Cuint}(0)
        size_ref = Ref{Csize_t}(sizeof(Cuint))
        ret = ccall(:sysctlbyname, Cint,
                    (Cstring, Ptr{Cvoid}, Ptr{Csize_t}, Ptr{Cvoid}, Csize_t),
                    "hw.cachelinesize", line_size, size_ref, C_NULL, 0)
        if ret == 0
            return Int(line_size[])
        else
            # Fallback: use getpagesize() to get the system page size.
            # clsize = ccall(:getpagesize, Cint, ())
            return FallbackCacheLineSize
        end
    elseif Sys.isunix()
        # Linux: use sysconf(_SC_LEVEL1_DCACHE_LINESIZE)
        line_size = ccall(:sysconf, Clong, (Cint,), _SC_LEVEL1_DCACHE_LINESIZE)
        if line_size > 0
            return Int(line_size)
        else
            return FallbackCacheLineSize
        end
    elseif Sys.iswindows()
        return get_l1_cache_line_size_windows()
    else
        return FallbackCacheLineSize
    end
end

function get_l1_cache_line_size_windows()::Int
    # First, determine the required buffer size.
    bufsize = Ref{UInt32}(0)
    ret = ccall((:GetLogicalProcessorInformationEx, "kernel32"),
                Cint, (Cint, Ptr{Cvoid}, Ptr{UInt32}),
                RELATION_CACHE, C_NULL, bufsize)
    if bufsize[] == 0
        error("Failed to obtain required buffer size.")
    end

    # Allocate the buffer.
    buffer = Vector{UInt8}(undef, bufsize[])
    ret = ccall((:GetLogicalProcessorInformationEx, "kernel32"),
                Cint, (Cint, Ptr{UInt8}, Ptr{UInt32}),
                RELATION_CACHE, buffer, bufsize)
    if ret == 0
        error("Failed to retrieve processor information.")
    end

    # The buffer now contains one+ SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX entries.
    # Each entry starts with an 8-byte header:
    #   - Bytes 0–3: Relationship (DWORD)
    #   - Bytes 4–7: Size (DWORD)
    # For cache entries, the CACHE_RELATIONSHIP structure begins at offset 8:
    #   - Byte 0: Cache Level (we want Level 1)
    #   - Bytes 2–3: Cache-Line Size (UInt16)
    ptr = pointer(buffer)
    offset = 0
    total_size = bufsize[]
    while offset < total_size
        entry_size = unsafe_load(Ptr{UInt32}(ptr + offset + 4))
        level = unsafe_load(Ptr{UInt8}(ptr + offset + 8))
        if level == 1
            line_size = unsafe_load(Ptr{UInt16}(ptr + offset + 10))
            return Int(line_size)
        end
        offset += entry_size
    end

    return FallbackCacheLineSize  # Fallback value.
end

@setup_workload CACHE_LINE_SIZE = begin
    detect_cache_line_size()
end

const CACHE_LINE_SIZE = AlignedAllocs.detect_cache_line_size()
# allocation error codes
const ENOMEM = Cint(12)  # Out of memory error code
const EINVAL = Cint(22)  # Invalid argument error code

"""
    memalign(::Type{T}, nitems::Integer, alignment::Integer=64) where T

__aligned uninitialized memory allocation__

Allocate memory for a densevector vec = Vector{T}(undef, nitems)
- vec starts at a memory address that is a multiple of `alignment` bytes
- Int(pointer(vec)) % alignment == 0

- alignment constrains the memory address of start of the vector 
- alignment is bitcount, (alignment * 8 is the alignment in bits)
- alignment must be a power of 2 and must be >= 16

`memalign` works on Unixes (Linux, Apple, Bsd), Windows
""" memalign

@inline function memalign(::Type{T}, nitems::Integer, alignment::Integer=CACHE_LINE_SIZE) where T
    @static Sys.iswindows() ? memalign_windows(T, nitems, alignment) : memalign_posix(T, nitems, alignment)
end

"""
    memalign_clear(::Type{T}, nitems::Integer, alignment=64) where T

__aligned zeroed memory allocation__

Allocate memory for a densevector vec = zeros(T, nitems)
- vec starts at a memory address that is a multiple of alignment bytes

`memalign_clear` works on Unixes (Linux, Apple, Bsd), Windows
""" memalign_clear

@inline function memalign_clear(::Type{T}, nitems::Integer, alignment::Integer=CACHE_LINE_SIZE) where T
    @static Sys.iswindows() ? memalign_clear_windows(T, nitems, alignment) : 
                              memalign_clear_posix(T, nitems, alignment)
end

@inline function memalign_clear_windows(::Type{T}, nitems::Integer, alignment::Integer) where T
    vec = memalign_windows(T, nitems, alignment)
    fill!(vec, zero(T))
    vec
end
        
@inline function memalign_clear_posix(::Type{T}, nitems::Integer, alignment::Integer) where T
    vec = memalign_posix(T, nitems, alignment)
    fill!(vec, zero(T))
    vec
end

# =================================================================================

function memalign_posix(::Type{T}, nitems::Integer, alignment::Integer) where T
    check_args(T, nitems, alignment)

    total_bytes = Base.checked_mul(nitems, sizeof(T))

    local ptr::Ptr{T} = Ptr{T}()
    memref = Ref{Ptr{Cvoid}}(C_NULL)
    ret = ccall((:posix_memalign), Cint,
                (Ref{Ptr{Cvoid}}, Csize_t, Csize_t),
                 memref, alignment, total_bytes)
    !iszero(ret) && alloc_error(ret)
    
    ptr = memref[]
    confirm_alignment(ptr, alignment) 
    
    # use the allocated memory as a Vector{T}(undef, nitems)
    vec = @GC.preserve ptr unsafe_wrap(Array, Ptr{T}(ptr), nitems; own=true)
    
    return vec
end

function memalign_windows(::Type{T}, nitems::Integer, alignment::Integer) where T
    check_args(T, nitems, alignment)
    
    total_bytes = Base.checked_mul(nitems, sizeof(T))
        
    local ptr::Ptr{T} = Ptr{T}()    
    ptr = ccall((:_aligned_malloc, "msvcrt"), Ptr{T},
                (Csize_t, Csize_t), total_bytes, alignment)        
    (ptr == C_NULL) && alloc_error(ENOMEM)

    confirm_alignment(ptr, alignment) 
    
    # use the allocated memory as a Vector{T}(undef, nitems)
    vec = @GC.preserve ptr unsafe_wrap(Array, Ptr{T}(ptr), nitems; own=false)
    
    # allow the GC to free the allocated memory
    finalizer(vec) do _
        @GC.preserve ptr ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{T},), ptr)
    end
    
    return vec
end

# =================================================================================

# error handling

function check_args(::Type{T}, nitems, alignment) where T
    isbitstype(T) || 
    throw(ArgumentError("element_type ($T) must be a `bitstype`"))

    nitems > 0 || 
    throw(ArgumentError("element_count ($nitems) must be > 0"))

    (ispow2(alignment) && alignment >= 16) || 
    throw(ArgumentError("Alignment ($alignment) must be 2^p where p >= 4"))
end

function confirm_alignment(ptr::Ptr, alignment::Integer)
    if UInt(ptr) % alignment != 0
        if Sys.iswindows()
            ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{Cvoid},), ptr)
        else
            ccall((:free, "Libc"), Cvoid, (Ptr{Cvoid},), ptr)
        end

        errmsg = "aligned memory allocation failed: returned address $(UInt(ptr)) is not aligned to $(alignment) bytes"
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


