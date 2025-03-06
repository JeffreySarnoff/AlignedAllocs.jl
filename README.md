# AlignedAllocs.jl
## lightweight cross-platform allocation of aligned memory 
#### Copyright 2025 by Jeffrey Sarnoff. Relased under the MIT License.
----

### exports

- `memalign(item_type, item_count, bytes_of_alignment)`
- `memalign_clear(item_type, item_count, bytes_of_alignment)`

### why it matters

Modern processors are organized to retrieve data in memory into chip local fast caches. At a practical level, the unit of memory retrieval is the cache line.  For most general purpose computing, the size of a cache line is 64 bytes (so one cache line holds 64 UInt8s, or 32 Int16s, or 16 Float32s, or 8 Float64s). When data is stored aligned to this size, its retreival is simpler and often quicker (crossing a cache line with say, a Float32 incurs costly delays).  

When using SIMD, alignment of 256 bytes (or more) is critical to getting the throughput one expects from SIMD operations.  Running unaligned data through SIMD slows the processing down a very great deal.


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

----

### also consider
[ArrayAllocators.jl](https://github.com/mkitti/ArrayAllocators.jl) - a much more developed approach to aligned arrays
  


