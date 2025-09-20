using PrecompileTools

const FallbackCacheLineSize = 64

# Linux: sysconf constant for L1 data cache line size.
const _SC_LEVEL1_DCACHE_LINESIZE = 190  # defined in <unistd.h>

# Windows: relationship identifier used by GetLogicalProcessorInformationEx.
const RELATION_CACHE = 2

function detect_cache_line_size()::Int
    if Sys.isapple()
        line_size = Ref{Cuint}(0)
        size_ref = Ref{Csize_t}(sizeof(Cuint))
        ret = ccall(:sysctlbyname, Cint,
                    (Cstring, Ptr{Cvoid}, Ptr{Csize_t}, Ptr{Cvoid}, Csize_t),
                    "hw.cachelinesize", line_size, size_ref, C_NULL, 0)
        return ret == 0 ? Int(line_size[]) : FallbackCacheLineSize
    elseif Sys.isunix()
        line_size = ccall(:sysconf, Clong, (Cint,), _SC_LEVEL1_DCACHE_LINESIZE)
        return line_size > 0 ? Int(line_size) : FallbackCacheLineSize
    elseif Sys.iswindows()
        return get_l1_cache_line_size_windows()
    else
        return FallbackCacheLineSize
    end
end

function get_l1_cache_line_size_windows()::Int
    bufsize = Ref{UInt32}(0)
    ret = ccall((:GetLogicalProcessorInformationEx, "kernel32"),
                Cint, (Cint, Ptr{Cvoid}, Ptr{UInt32}),
                RELATION_CACHE, C_NULL, bufsize)
    if bufsize[] == 0
        @warn "GetLogicalProcessorInformationEx returned zero buffer size; using fallback cache line size." ret
        return FallbackCacheLineSize
    end

    buffer = Vector{UInt8}(undef, bufsize[])
    ret = ccall((:GetLogicalProcessorInformationEx, "kernel32"),
                Cint, (Cint, Ptr{UInt8}, Ptr{UInt32}),
                RELATION_CACHE, buffer, bufsize)
    if ret == 0
        @warn "GetLogicalProcessorInformationEx failed; using fallback cache line size." ret
        return FallbackCacheLineSize
    end

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

    @warn "No L1 cache information found; using fallback cache line size."
    return FallbackCacheLineSize
end

function _compute_cache_line_size()::Int
    size = detect_cache_line_size()
    return size > 0 ? size : FallbackCacheLineSize
end

@setup_workload begin
    @compile_workload begin
        detect_cache_line_size()
    end
end

const CACHE_LINE_SIZE = try
    _compute_cache_line_size()
catch err
    @warn "Failed to detect cache line size; using fallback." exception = (err, catch_backtrace())
    FallbackCacheLineSize
end