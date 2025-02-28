"""
    llvm_prefetch( ptr::Ptr{UInt8}, rw=Int32(0), locality=Int32(3), cachetype=Int32(1))

prefetch the memory at ptr for repeated reading from datacache
"""
"""
    llvm_prefetch(ptr; rw::Int32=Int32(0), locality::Int32=Int32(3), cache_type::Int32=Int32(1))

Wrapper for LLVM's prefetch intrinsic with sensible defaults, implemented using llvmcall.

# Arguments
- `ptr`: Memory address to prefetch (can be any pointer or array element)
- `rw`: Read/write specifier (0 = read [default], 1 = write)
- `locality`: Temporal locality (0 = none, 1 = low, 2 = moderate, 3 = high [default])
- `cache_type`: Cache type (0 = instruction, 1 = data [default])

# Examples
```julia
# Basic usage with default parameters (read, high locality, data cache)
x = rand(1000, 1000)
llvm_prefetch(pointer(x, 500))

# In a loop with explicit prefetching ahead
function process_with_prefetch(arr::Vector{Float64})
    n = length(arr)
    for i in 1:n-16
        # Prefetch data 16 elements ahead
        llvm_prefetch(pointer(arr, i+16))
        
        # Process current element
        arr[i] = arr[i] * 2
    end
    
    # Process remaining elements without prefetch
    for i in (n-15):n
        arr[i] = arr[i] * 2
    end
    return arr
end
```
"""
function llvm_prefetch(ptr::Ptr{T}; rw::Int32=Int32(0), locality::Int32=Int32(3), cache_type::Int32=Int32(1)) where T
    # Input validation for safer usage
    @assert rw in (Int32(0), Int32(1)) "rw must be 0 (read) or 1 (write)"
    @assert locality in (Int32(0), Int32(1), Int32(2), Int32(3)) "locality must be between 0 and 3"
    @assert cache_type in (Int32(0), Int32(1)) "cache_type must be 0 (instruction) or 1 (data)"
    
    # LLVM IR for the prefetch intrinsic
    ir = """
        %ptr = inttoptr i64 %0 to i8*
        call void @llvm.prefetch(i8* %ptr, i32 %1, i32 %2, i32 %3)
        ret void
        
        declare void @llvm.prefetch(i8*, i32, i32, i32)
    """
    
    # Call the LLVM intrinsic using llvmcall
    Base.llvmcall(ir, Nothing, Tuple{UInt64, Int32, Int32, Int32}, 
                 UInt64(ptr), rw, locality, cache_type)
    
    # Function doesn't return a value
    return nothing
end

# Alternative version with type stability for different pointer types
# This avoids type instability when using different pointer types
"""
    llvm_prefetch_raw(ptr_value::UInt64; rw::Int32=Int32(0), locality::Int32=Int32(3), cache_type::Int32=Int32(1))

Low-level prefetch function that takes a raw memory address as UInt64.
Use this when you need to control the exact address to prefetch.
"""
function llvm_prefetch_raw(ptr_value::UInt64; rw::Int32=Int32(0), locality::Int32=Int32(3), cache_type::Int32=Int32(1))
    # Input validation for safer usage
    @assert rw in (Int32(0), Int32(1)) "rw must be 0 (read) or 1 (write)"
    @assert locality in (Int32(0), Int32(1), Int32(2), Int32(3)) "locality must be between 0 and 3"
    @assert cache_type in (Int32(0), Int32(1)) "cache_type must be 0 (instruction) or 1 (data)"
    
    # LLVM IR for the prefetch intrinsic
    ir = """
        %ptr = inttoptr i64 %0 to i8*
        call void @llvm.prefetch(i8* %ptr, i32 %1, i32 %2, i32 %3)
        ret void
        
        declare void @llvm.prefetch(i8*, i32, i32, i32)
    """
    
    # Call the LLVM intrinsic using llvmcall
    Base.llvmcall(ir, Nothing, Tuple{UInt64, Int32, Int32, Int32}, 
                 ptr_value, rw, locality, cache_type)
    
    # Function doesn't return a value
    return nothing
end

# Convenience method for any pointer type
function llvm_prefetch(ptr; kwargs...)
    llvm_prefetch_raw(UInt64(ptr); kwargs...)
end

# Convenience method for array elements
function llvm_prefetch(arr::AbstractArray, idx::Integer; kwargs...)
    # Bounds checking for memory safety
    @boundscheck checkbounds(arr, idx)
    
    # Get pointer to the specific element
    ptr = pointer(arr, idx)
    
    # Call the main prefetch function
    llvm_prefetch(ptr; kwargs...)
end

# Helper for prefetching multiple elements ahead in array traversal
"""
    prefetch_ahead(arr::AbstractArray, current_idx::Integer, prefetch_distance::Integer=16; kwargs...)

Prefetch an element some distance ahead of the current position in an array.
Safely handles bounds checking.

# Arguments
- `arr`: The array being traversed
- `current_idx`: The current position in the array
- `prefetch_distance`: How many elements ahead to prefetch (default: 16)
- `kwargs...`: Additional parameters to pass to `llvm_prefetch`
"""
function prefetch_ahead(arr::AbstractArray, current_idx::Integer, prefetch_distance::Integer=16; kwargs...)
    future_idx = current_idx + prefetch_distance
    
    # Only prefetch if the future index is within bounds
    if checkbounds(Bool, arr, future_idx)
        llvm_prefetch(arr, future_idx; kwargs...)
    end
    
    return nothing
end

"""
    llvm_prefetch(ptr; rw::Int32=Int32(0), locality::Int32=Int32(3), cache_type::Int32=Int32(1))

<prompt>
using Julia, Julia best practices, Julia safe and robust techniques, 
write a function llvm_prefetch that wraps the llvm intrisinc prefetch
and sets the arguments rw=Int32(0), locality=Int32(3), cachetype=Int32(1).
<Claude 3.7 sonnet>
rework the function use Base.llvmcall
<Claude 3.7 sonnet>

"""

#=
    llvm_prefetch(ptr; rw::Int32=Int32(0), locality::Int32=Int32(3), cache_type::Int32=Int32(1))

Wrapper for LLVM's prefetch intrinsic with sensible defaults, implemented using llvmcall.

# Arguments
- `ptr`: Memory address to prefetch (can be any pointer or array element)
- `rw`: Read/write specifier (0 = read [default], 1 = write)
- `locality`: Temporal locality (0 = none, 1 = low, 2 = moderate, 3 = high [default])
- `cache_type`: Cache type (0 = instruction, 1 = data [default])

# Examples
```julia
# Basic usage with default parameters (read, high locality, data cache)
x = rand(1000, 1000)
llvm_prefetch(pointer(x, 500))

# In a loop with explicit prefetching ahead
function process_with_prefetch(arr::Vector{Float64})
    n = length(arr)
    for i in 1:n-16
        # Prefetch data 16 elements ahead
        llvm_prefetch(pointer(arr, i+16))
        
        # Process current element
        arr[i] = arr[i] * 2
    end
    
    # Process remaining elements without prefetch
    for i in (n-15):n
        arr[i] = arr[i] * 2
    end
    return arr
end
```
"""
function llvm_prefetch(ptr::Ptr{T}; rw::Int32=Int32(0), locality::Int32=Int32(3), cache_type::Int32=Int32(1)) where T
    # Input validation for safer usage
    @assert rw in (Int32(0), Int32(1)) "rw must be 0 (read) or 1 (write)"
    @assert locality in (Int32(0), Int32(1), Int32(2), Int32(3)) "locality must be between 0 and 3"
    @assert cache_type in (Int32(0), Int32(1)) "cache_type must be 0 (instruction) or 1 (data)"
    
    # LLVM IR for the prefetch intrinsic
    ir = """
        %ptr = inttoptr i64 %0 to i8*
        call void @llvm.prefetch(i8* %ptr, i32 %1, i32 %2, i32 %3)
        ret void
        
        declare void @llvm.prefetch(i8*, i32, i32, i32)
    """
    
    # Call the LLVM intrinsic using llvmcall
    Base.llvmcall(ir, Nothing, Tuple{UInt64, Int32, Int32, Int32}, 
                 UInt64(ptr), rw, locality, cache_type)
    
    # Function doesn't return a value
    return nothing
end

# Alternative version with type stability for different pointer types
# This avoids type instability when using different pointer types
"""
    llvm_prefetch_raw(ptr_value::UInt64; rw::Int32=Int32(0), locality::Int32=Int32(3), cache_type::Int32=Int32(1))

Low-level prefetch function that takes a raw memory address as UInt64.
Use this when you need to control the exact address to prefetch.
"""
function llvm_prefetch_raw(ptr_value::UInt64; rw::Int32=Int32(0), locality::Int32=Int32(3), cache_type::Int32=Int32(1))
    # Input validation for safer usage
    @assert rw in (Int32(0), Int32(1)) "rw must be 0 (read) or 1 (write)"
    @assert locality in (Int32(0), Int32(1), Int32(2), Int32(3)) "locality must be between 0 and 3"
    @assert cache_type in (Int32(0), Int32(1)) "cache_type must be 0 (instruction) or 1 (data)"
    
    # LLVM IR for the prefetch intrinsic
    ir = """
        %ptr = inttoptr i64 %0 to i8*
        call void @llvm.prefetch(i8* %ptr, i32 %1, i32 %2, i32 %3)
        ret void
        
        declare void @llvm.prefetch(i8*, i32, i32, i32)
    """
    
    # Call the LLVM intrinsic using llvmcall
    Base.llvmcall(ir, Nothing, Tuple{UInt64, Int32, Int32, Int32}, 
                 ptr_value, rw, locality, cache_type)
    
    # Function doesn't return a value
    return nothing
end

# Convenience method for any pointer type
function llvm_prefetch(ptr; kwargs...)
    llvm_prefetch_raw(UInt64(ptr); kwargs...)
end

# Convenience method for array elements
function llvm_prefetch(arr::AbstractArray, idx::Integer; kwargs...)
    # Bounds checking for memory safety
    @boundscheck checkbounds(arr, idx)
    
    # Get pointer to the specific element
    ptr = pointer(arr, idx)
    
    # Call the main prefetch function
    llvm_prefetch(ptr; kwargs...)
end

# Helper for prefetching multiple elements ahead in array traversal
"""
    prefetch_ahead(arr::AbstractArray, current_idx::Integer, prefetch_distance::Integer=16; kwargs...)

Prefetch an element some distance ahead of the current position in an array.
Safely handles bounds checking.

# Arguments
- `arr`: The array being traversed
- `current_idx`: The current position in the array
- `prefetch_distance`: How many elements ahead to prefetch (default: 16)
- `kwargs...`: Additional parameters to pass to `llvm_prefetch`
"""
function prefetch_ahead(arr::AbstractArray, current_idx::Integer, prefetch_distance::Integer=16; kwargs...)
    future_idx = current_idx + prefetch_distance
    
    # Only prefetch if the future index is within bounds
    if checkbounds(Bool, arr, future_idx)
        llvm_prefetch(arr, future_idx; kwargs...)
    end
    
    return nothing
end
            

Wrapper for LLVM's prefetch intrinsic with sensible defaults.

# Arguments
- `ptr`: Memory address to prefetch (can be any pointer or array element)
- `rw`: Read/write specifier (0 = read [default], 1 = write)
- `locality`: Temporal locality (0 = none, 1 = low, 2 = moderate, 3 = high [default])
- `cache_type`: Cache type (0 = instruction, 1 = data [default])

# Examples
```julia
# Basic usage with default parameters (read, high locality, data cache)
x = rand(1000, 1000)
llvm_prefetch(pointer(x, 500))

# In a loop with explicit prefetching ahead
function process_with_prefetch(arr::Vector{Float64})
    n = length(arr)
    for i in 1:n-16
        # Prefetch data 16 elements ahead
        llvm_prefetch(pointer(arr, i+16))
        
        # Process current element
        arr[i] = arr[i] * 2
    end
    
    # Process remaining elements without prefetch
    for i in (n-15):n
        arr[i] = arr[i] * 2
    end
    return arr
end
```
"""
function llvm_prefetch(ptr; rw::Int32=Int32(0), locality::Int32=Int32(3), cache_type::Int32=Int32(1))
    # Input validation for safer usage
    @assert rw in (Int32(0), Int32(1)) "rw must be 0 (read) or 1 (write)"
    @assert locality in (Int32(0), Int32(1), Int32(2), Int32(3)) "locality must be between 0 and 3"
    @assert cache_type in (Int32(0), Int32(1)) "cache_type must be 0 (instruction) or 1 (data)"
    
    # Call the LLVM intrinsic
    Base.@llvm.prefetch(ptr, rw, locality, cache_type)
    
    # Function doesn't return a value
    return nothing
end

# Convenience method for array elements
function llvm_prefetch(arr::AbstractArray, idx::Integer; kwargs...)
    # Bounds checking for memory safety
    @boundscheck checkbounds(arr, idx)
    
    # Get pointer to the specific element
    ptr = pointer(arr, idx)
    
    # Call the main prefetch function
    llvm_prefetch(ptr; kwargs...)
end

# Helper for prefetching multiple elements ahead in array traversal
"""
    prefetch_ahead(arr::AbstractArray, current_idx::Integer, prefetch_distance::Integer=16; kwargs...)

Prefetch an element some distance ahead of the current position in an array.
Safely handles bounds checking.

# Arguments
- `arr`: The array being traversed
- `current_idx`: The current position in the array
- `prefetch_distance`: How many elements ahead to prefetch (default: 16)
- `kwargs...`: Additional parameters to pass to `llvm_prefetch`
"""
function prefetch_ahead(arr::AbstractArray, current_idx::Integer, prefetch_distance::Integer=16; kwargs...)
    future_idx = current_idx + prefetch_distance
    
    # Only prefetch if the future index is within bounds
    if checkbounds(Bool, arr, future_idx)
        llvm_prefetch(arr, future_idx; kwargs...)
    end
    
    return nothing
end

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
=#
