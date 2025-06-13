#=
   note:
   Some of this is the result of many iterations and refinements of multiple ai tools
   working on each other's output, each iteration guided by my directions. Some is not.
=#

using PrecompileTools

# Top-Level Constants and (Optional) Struct Declarations
const FallbackCacheLineSize = 64

# Top-Level Constants and (Optional) Struct Declarations

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
