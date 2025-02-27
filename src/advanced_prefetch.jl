module CachePrefetch

export prefetch_address, prefetch_specific_cache_line, align_to_cache_line, 
       get_cache_line_size, prefetch_array_ahead

"""
    get_cache_line_size()

Returns the cache line size in bytes for the current architecture.
On most modern CPUs this is 64 bytes.
"""
function get_cache_line_size()
    # In production code, this could be determined dynamically based on CPU architecture
    # For example, using CPUID instruction on x86/x64
    return 64
end

"""
    prefetch_address(ptr::Ptr{T}, rw::Integer=0, locality::Integer=3) where T

Prefetch the cache line containing the memory address pointed to by `ptr`.

# Arguments
- `ptr`: Pointer to the memory location to prefetch
- `rw`: Read/write hint (0 for read, 1 for write)
- `locality`: Temporal locality hint (0 = no temporal locality, 3 = high temporal locality)

This is the equivalent of `__builtin_prefetch` in C/C++.
"""
@inline function prefetch_address(ptr::Ptr{T}, rw::Integer=0, locality::Integer=3) where T
    # Validate input parameters
    @assert 0 <= rw <= 1 "rw must be 0 (read) or 1 for write"
    @assert 0 <= locality <= 3 "locality must be between 0 and 3"
    
    # Use GC.@preserve to ensure the pointer isn't garbage collected
    GC.@preserve ptr begin
        # Convert pointer to Integer for llvmcall
        ptr_int = reinterpret(UInt64, ptr)
        
        # Call LLVM prefetch intrinsic
        Base.llvmcall(
            ("""
            declare void @llvm.prefetch(i8* %0, i32 %1, i32 %2, i32 %3)
            define void @prefetch_fn(i64 %addr, i32 %rw, i32 %loc, i32 %cache) {
                %ptr = inttoptr i64 %addr to i8*
                call void @llvm.prefetch(i8* %ptr, i32 %rw, i32 %loc, i32 %cache)
                ret void
            }
            """, "prefetch_fn"),
            Cvoid,
            Tuple{UInt64, Int32, Int32, Int32},
            ptr_int, Int32(rw), Int32(locality), Int32(1)  # Last param is cache type (1 = data cache)
        )
    end
    
    return nothing
end

"""
    align_to_cache_line(ptr::Ptr{T}) where T

Return a pointer aligned to the start of the cache line containing `ptr`.

# Arguments
- `ptr`: Pointer to align to cache line boundary

# Returns
A pointer to the start of the cache line
"""
@inline function align_to_cache_line(ptr::Ptr{T}) where T
    line_size = get_cache_line_size()
    ptr_int = reinterpret(UInt64, ptr)
    
    # Mask off the lower bits to align to cache line boundary
    aligned_ptr_int = ptr_int & ~(UInt64(line_size - 1))
    
    return reinterpret(Ptr{T}, aligned_ptr_int)
end

"""
    prefetch_specific_cache_line(base_ptr::Ptr{T}, line_offset::Integer, 
                               rw::Integer=0, locality::Integer=3) where T

Prefetch a specific cache line at a given offset from a base pointer.

# Arguments
- `base_ptr`: Base pointer to calculate the cache line from
- `line_offset`: Number of cache lines to offset from the base pointer
- `rw`: Read/write hint (0 for read, 1 for write)
- `locality`: Temporal locality hint (0 = no temporal locality, 3 = high temporal locality)

This allows precise targeting of specific cache lines relative to a known address.
"""
@inline function prefetch_specific_cache_line(base_ptr::Ptr{T}, line_offset::Integer, 
                                            rw::Integer=0, locality::Integer=3) where T
    # Validate input parameters
    @assert 0 <= rw <= 1 "rw must be 0 (read) or 1 for write"
    @assert 0 <= locality <= 3 "locality must be between 0 and 3"
    
    # First align the base pointer to a cache line boundary
    aligned_base = align_to_cache_line(base_ptr)
    
    # Calculate the address of the specific cache line
    line_size = get_cache_line_size()
    offset_bytes = line_offset * line_size
    
    # Create a pointer to the target cache line
    target_ptr = aligned_base + offset_bytes
    
    # Perform the prefetch
    prefetch_address(target_ptr, rw, locality)
    
    return nothing
end

"""
    prefetch_array_ahead(arr::AbstractArray{T}, current_index::Integer, 
                        look_ahead::Integer=1, rw::Integer=0, locality::Integer=3) where T

Prefetch array elements ahead of the current processing position.

# Arguments
- `arr`: Array being processed
- `current_index`: Current array index being processed
- `look_ahead`: Number of elements to look ahead for prefetching
- `rw`: Read/write hint (0 for read, 1 for write)
- `locality`: Temporal locality hint (0 = no temporal locality, 3 = high temporal locality)

This is optimized for common array-processing scenarios where you want to
prefetch data that will be needed soon in a processing loop.
"""
@inline function prefetch_array_ahead(arr::AbstractArray{T}, current_index::Integer, 
                                    look_ahead::Integer=1, rw::Integer=0, locality::Integer=3) where T
    target_idx = current_index + look_ahead
    
    if 1 <= target_idx <= length(arr)
        prefetch_address(pointer(arr, target_idx), rw, locality)
    end
    
    return nothing
end

"""
    prefetch_stride(base_ptr::Ptr{T}, elements_per_cacheline::Integer, 
                  stride::Integer, num_prefetch::Integer=1, 
                  rw::Integer=0, locality::Integer=3) where T

Prefetch data with a specific stride pattern, useful for non-contiguous memory access.

# Arguments
- `base_ptr`: Base pointer to the start of the data structure
- `elements_per_cacheline`: Number of elements that fit in one cache line
- `stride`: Number of elements to skip for each access
- `num_prefetch`: Number of stride iterations to prefetch ahead
- `rw`: Read/write hint (0 for read, 1 for write) 
- `locality`: Temporal locality hint (0 = no temporal locality, 3 = high temporal locality)

This is especially useful for matrix operations where memory access isn't contiguous.
"""
@inline function prefetch_stride(base_ptr::Ptr{T}, elements_per_cacheline::Integer, 
                               stride::Integer, num_prefetch::Integer=1, 
                               rw::Integer=0, locality::Integer=3) where T
    element_size = sizeof(T)
    
    for i in 1:num_prefetch
        # Calculate offset in bytes
        offset = stride * i * element_size
        target_ptr = base_ptr + offset
        
        prefetch_address(target_ptr, rw, locality)
    end
    
    return nothing
end

end # module
