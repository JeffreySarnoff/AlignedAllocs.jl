# AlignedAllocs.jl
## lightweight cross-platform allocation of aligned memory 
#### Copyright 2025 by Jeffrey Sarnoff. Relased under the MIT License.
----

### exports

- `memalign(item_type, item_count, bytes_of_alignment; zeros=false)`

```
memalign_zeros(item_type, item_count, bytes_of_alignment) =
    memalign(item_type, item_count, bytes_of_alignment; zeros=true)
```
  
```
#  vec::DenseVector = memalign(item_type, item_count, nbyte_alignment = 64)
#                              bitstype ,    > 0    ,   2^p where p > 2

element_type      = Float32   # a type T for which isbitstype(T) is true
element_count     = 1024
element_bytes     = sizeof(element_type) * element_count

bytesofalignment  = 64 # bytes

vec = memalign(element_type, element_count, bytesofalignment)
  
vec behaves as a DenseVector with enhanced cache-line performance
vec is unsafe_wrapped contiguous memory provided by LLVM intrinsic or C/C++ library functions
```

```
unsafe_wrap(Array, ptr, dims; own = false, reinterpret = false)
    Array: The array type to create (typically Array)
    ptr: A pointer to the existing memory to wrap
    dims: Dimensions of the array to create (tuple or single integer)

    own: Boolean indicating whether the resulting array should take ownership of the memory
        When true: Memory will be freed when the array is garbage collected
        When false (default): User is responsible for memory management

    reinterpret: Controls data reinterpretation
        When false (default): No reinterpretation
        When a type is provided: Data is reinterpreted as that type

        The reinterpret keyword parameter in unsafe_wrap provides a powerful way to view memory
            of one type as another type without copying data, similar to type casting in C
            improved with Julia's type system awareness.

        When provided, reinterpret changes how the underlying memory is interpreted:
            reinterpret = false (default): Memory is interpreted as the pointer's type
            reinterpret = SomeType: Memory is interpreted as containing elements of SomeType instead

        Technical Considerations
        
        Size compatibility: sizeof(PointerType) * length must be divisible by sizeof(ReinterpretType)
        Alignment: Must respect the alignment requirements of the target type
        The returned array's size is adjusted based on type size differences
        Particularly useful for SIMD operations where specific memory layouts can improve performance
        
        This parameter is crucial for zero-copy interoperation with external libraries
        and efficient memory representation transformations.
```

```
EXAMPLES
    # Creating an array from C-allocated memory
        ptr = Libc.malloc(sizeof(Float64) * 10)
        x = unsafe_wrap(Array, convert(Ptr{Float64}, ptr), 10, own=true)
    # Working with aligned memory for SIMD
        using Base.Threads
        ptr = align_alloc(64, sizeof(Float32) * 16)  # 64-byte aligned allocation
        aligned_array = unsafe_wrap(Array, convert(Ptr{Float32}, ptr), 16)

    # SIMD-friendly memory layout conversion
        # View color channels as SIMD-friendly aligned structures
        rgba_buffer = Vector{UInt8}(undef, 4 * width * height)
        # Use as array of RGBA pixels without copying
        pixels = unsafe_wrap(Array, convert(Ptr{NTuple{4,UInt8}}, pointer(rgba_buffer)), 
                             width * height, reinterpret=NTuple{4,UInt8})

    # View Float64 bits as UInt64
        x = [1.0, 2.0, 3.0]
        ptr = pointer(x)
        y = unsafe_wrap(Array, ptr, length(x), reinterpret=UInt64)

    # Read a C structure from binary data
        struct Point
            x::Float32
            y::Float32
        end
        
        buffer = Vector{UInt8}(undef, 1000)
        # ... fill buffer with data ...
        points = unsafe_wrap(Array, convert(Ptr{Point}, pointer(buffer)), 
                             div(length(buffer), sizeof(Point)), 
                             reinterpret=Point)

```
----

### also consider
[ArrayAllocators.jl](https://github.com/mkitti/ArrayAllocators.jl) - a much more developed approach to aligned arrays
  


