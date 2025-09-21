using PrecompileTools

const FallbackCacheLineSize = 64

const _SC_LEVEL1_DCACHE_LINESIZE = 190  # defined in <unistd.h>

@static if Sys.iswindows()
    const RELATION_CACHE = 2  # LOGICAL_PROCESSOR_RELATIONSHIP.RelationCache

    function _windows_cache_line_size()::Int
        bufsize = Ref{UInt32}(0)
        ccall((:GetLogicalProcessorInformationEx, "kernel32"),
              Cint, (Cint, Ptr{Cvoid}, Ptr{UInt32}),
              RELATION_CACHE, C_NULL, bufsize)

        if bufsize[] == 0
            @warn "GetLogicalProcessorInformationEx returned zero buffer size; using fallback cache line size."
            return FallbackCacheLineSize
        end

        buffer = Base.Vector{UInt8}(undef, bufsize[])
        ret = ccall((:GetLogicalProcessorInformationEx, "kernel32"),
                    Cint, (Cint, Ptr{UInt8}, Ptr{UInt32}),
                    RELATION_CACHE, buffer, bufsize)
        if ret == 0
            @warn "GetLogicalProcessorInformationEx failed; using fallback cache line size." ret
            return FallbackCacheLineSize
        end

        GC.@preserve buffer begin
            base_ptr = pointer(buffer)
            offset = 0
            limit = Int(bufsize[])
            while offset < limit
                entry_size = Int(unsafe_load(Ptr{UInt32}(base_ptr + offset + 4)))
                if entry_size <= 0
                    break
                end

                level = unsafe_load(Ptr{UInt8}(base_ptr + offset + 8))
                if level == 1
                    line_size = unsafe_load(Ptr{UInt16}(base_ptr + offset + 10))
                    return Int(line_size)
                end

                offset += entry_size
            end
        end

        @warn "No L1 cache information found; using fallback cache line size."
        return FallbackCacheLineSize
    end
end

@inline function _detect_cache_line_size()::Int
    @static if Sys.isapple()
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
        return _windows_cache_line_size()
    else
        return FallbackCacheLineSize
    end
end

@setup_workload begin
    @compile_workload begin
        _detect_cache_line_size()
    end
end

const CACHE_LINE_SIZE = let size = try
        _detect_cache_line_size()
    catch err
        @warn "Failed to detect cache line size; using fallback." exception = (err, catch_backtrace())
        FallbackCacheLineSize
    end
    size > 0 ? size : FallbackCacheLineSize
end

