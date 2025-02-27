"""
    prefetch_cacheline(ptr::Ptr{T}, temporal::Bool=true, locality::Int=3) where T

Prefetch the cache line containing the memory at address `ptr` into the processor's cache.

Parameters:
- `ptr`: Pointer to the memory address to prefetch
- `temporal`: Whether the data should be kept in cache (true) or fetched and then discarded (false)
- `locality`: Hint for spatial locality (0=no locality, 3=high locality)

This is an inline function that maps to LLVM's prefetch intrinsic.
"""
@inline function prefetch_cacheline(ptr::Ptr{T}, temporal::Bool=true, locality::Int=3) where T
    # Validate locality parameter
    if !(0 ≤ locality ≤ 3)
        throw(ArgumentError("Locality must be between 0 and 3"))
    end
    
    # Call Julia's built-in prefetch function
    # This maps to LLVM's prefetch intrinsic
    Base.llvmcall(
        """
        %ptr = inttoptr i64 %0 to i8*
        call void @llvm.prefetch(i8* %ptr, i32 %1, i32 %2, i32 1)
        ret void
        """,
        Cvoid,
        Tuple{UInt64, Int32, Int32},
        reinterpret(UInt64, ptr),
        temporal ? Int32(0) : Int32(1),  # 0 for temporal, 1 for non-temporal
        Int32(locality)
    )
    
    return nothing
end

# Convenience method for prefetching array elements
@inline function prefetch_cacheline(arr::Array{T}, index::Integer, temporal::Bool=true, locality::Int=3) where T
    if 1 ≤ index ≤ length(arr)
        prefetch_cacheline(pointer(arr, index), temporal, locality)
    end
    return nothing
end
