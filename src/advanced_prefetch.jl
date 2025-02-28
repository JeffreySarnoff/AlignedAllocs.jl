"""
When you call prefetch(ptr, Val(L), Val(RW)), Julia will inline this and emit a processor-specific prefetch instruction (on x86-64, for example, locality hints 0–3 map to prefetchnta, prefetcht2, prefetcht1, and prefetcht0 respectively). This is purely a hint to the CPU – it does not read the data immediately, but it signals the processor to start loading that memory into cache. There is no return value (prefetching is just a hint), and the operation is safe as long as the pointer is valid. By using a generated function with strict argument checking, we follow Julia best practices to catch mistakes early and avoid runtime overhead. Marking it with @inline (which generated functions are by default) ensures it won’t add function call overhead in tight loops.When to use prefetching: Use prefetch only in performance-critical code where cache misses are a proven bottleneck. This typically applies when you have:

Large data sets or streaming data where working set sizes exceed the cache (e.g. processing arrays larger than tens of kilobytes).
Irregular memory access patterns (like pointer chasing in graphs or trees, hash table lookups, etc.) that hardware prefetchers and compilers cannot easily predict​. In such cases, you can manually prefetch a few iterations ahead or prefetch a data structure early, do other work, and then use the data when it’s likely loaded into L1 cache​.
By prefetching data before you actually need it, you overlap memory latency with useful computation, which can significantly reduce stall time due to cache misses​. For example, in a loop you might call prefetch(pointer(A, i+16), Val(3), Val(0)) to hint that you will soon read element A[i+16], allowing the CPU to start loading it while you process the current iteration.Important considerations: Not all situations benefit from prefetching. Modern processors already have sophisticated hardware prefetchers that handle sequential or simple strided access patterns, so manual prefetching is usually unnecessary in those cases. In fact, incorrect use of prefetch can waste bandwidth or evict useful data from the cache. Always profile your code to ensure that cache misses are a problem before adding prefetch calls. When used judiciously in the right scenarios, however, manual prefetch hints can lead to substantial speedups by reducing memory stall time​
"""

# Prefetch a memory address into cache (similar to GCC's __builtin_prefetch)
@generated function prefetch(ptr::Ptr{Cvoid}, ::Val{L}=Val(3), ::Val{RW}=Val(0)) where {L,RW}
    # Validate locality (L) and read/write (RW) constants at compile time
    L ∈ 0:3 || throw(ArgumentError("Prefetch locality must be 0–3, got $L"))
    RW ∈ 0:1 || throw(ArgumentError("Prefetch mode must be 0 (read) or 1 (write), got $RW"))
    # Define the LLVM intrinsic and emit the IR code with the given constants
    decl = "declare void @llvm.prefetch(i8*, i32, i32, i32)"
    ir = """
        %addr = inttoptr $JULIAPOINTERTYPE %0 to i8*
        call void @llvm.prefetch(i8* %addr, i32 $RW, i32 $L, i32 1)
        ret void
    """
    return :((Base.llvmcall(($(decl), $ir), Cvoid, Tuple{Ptr{Cvoid}}, ptr)))
end

#=
When you call prefetch(ptr, Val(L), Val(RW)), Julia will inline this and emit a processor-specific prefetch instruction (on x86-64, for example, locality hints 0–3 map to prefetchnta, prefetcht2, prefetcht1, and prefetcht0 respectively). This is purely a hint to the CPU – it does not read the data immediately, but it signals the processor to start loading that memory into cache. There is no return value (prefetching is just a hint), and the operation is safe as long as the pointer is valid. By using a generated function with strict argument checking, we follow Julia best practices to catch mistakes early and avoid runtime overhead. Marking it with @inline (which generated functions are by default) ensures it won’t add function call overhead in tight loops.When to use prefetching: Use prefetch only in performance-critical code where cache misses are a proven bottleneck. This typically applies when you have:
Large data sets or streaming data where working set sizes exceed the cache (e.g. processing arrays larger than tens of kilobytes)​
DISCOURSE.JULIALANG.ORG
.
Irregular memory access patterns (like pointer chasing in graphs or trees, hash table lookups, etc.) that hardware prefetchers and compilers cannot easily predict​
DISCOURSE.JULIALANG.ORG
​
DISCOURSE.JULIALANG.ORG
. In such cases, you can manually prefetch a few iterations ahead or prefetch a data structure early, do other work, and then use the data when it’s likely loaded into L1 cache​
DISCOURSE.JULIALANG.ORG
.
By prefetching data before you actually need it, you overlap memory latency with useful computation, which can significantly reduce stall time due to cache misses​
DISCOURSE.JULIALANG.ORG
. For example, in a loop you might call prefetch(pointer(A, i+16), Val(3), Val(0)) to hint that you will soon read element A[i+16], allowing the CPU to start loading it while you process the current iteration.Important considerations: Not all situations benefit from prefetching. Modern processors already have sophisticated hardware prefetchers that handle sequential or simple strided access patterns, so manual prefetching is usually unnecessary in those cases. In fact, incorrect use of prefetch can waste bandwidth or evict useful data from the cache. Always profile your code to ensure that cache misses are a problem before adding prefetch calls. When used judiciously in the right scenarios, however, manual prefetch hints can lead to substantial speedups by reducing memory stall time​
DISCOURSE.JULIALANG.ORG
. Use it as a targeted optimization when you have identified a memory-bound section where the access pattern is not handled well by automatic caching mechanisms.References: The implementation above is based on known techniques from the Julia community. For instance, the VectorizationBase.jl package provides a similar prefetch intrinsic implementation using llvmcall​
DISCOURSE.JULIALANG.ORG
, and the approach follows the same semantics as GCC’s __builtin_prefetch documented in Clang/LLVM’s language extensions​
CLANG.LLVM.ORG
. These sources reinforce that our implementation is correct and optimized for high-performance processors.
=#



"""
    prefetch(ptr::Ptr{T}, rw::Integer=0, locality::Integer=3) where T

Prefetch the data at memory address `ptr` into the CPU cache.

# Arguments
- `ptr`: The memory address to prefetch.
- `rw`: Read/write hint (0 for read, 1 for write).
- `locality`: Temporal locality hint (0-3, where 3 means high locality, 0 means low locality).

This function provides Julia access to the LLVM prefetch intrinsic, equivalent to C/C++'s
`__builtin_prefetch`.
"""
function prefetch(ptr::Ptr{T}, rw::Integer=0, locality::Integer=3) where T
    @assert 0 <= rw <= 1 "rw must be 0 (read) or 1 (write)"
    @assert 0 <= locality <= 3 "locality must be between 0 and 3"
    
    ptr_i8 = convert(Ptr{UInt8}, ptr)
    
    Base.llvmcall(
        ("""
        declare void @llvm.prefetch(i8* %addr, i32 %rw, i32 %locality, i32 %cache_type)
        
        define void @prefetch_func(i8* %addr, i32 %rw, i32 %locality) {
            call void @llvm.prefetch(i8* %addr, i32 %rw, i32 %locality, i32 1)
            ret void
        }
        """, "prefetch_func"),
        Cvoid,
        Tuple{Ptr{UInt8}, Int32, Int32},
        ptr_i8, Int32(rw), Int32(locality)
    )
end

"""
    prefetch(arr::AbstractArray{T}, index, rw::Integer=0, locality::Integer=3) where T

Prefetch the element at `index` of array `arr` into the cache.

See `prefetch(ptr, rw, locality)` for details on the parameters.
"""
function prefetch(arr::AbstractArray{T}, index, rw::Integer=0, locality::Integer=3) where T
    @boundscheck checkbounds(arr, index)
    ptr = pointer(arr, index)
    prefetch(ptr, rw, locality)
end

#=
   most of this comes from extended refinement with chatgpt
=#

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
