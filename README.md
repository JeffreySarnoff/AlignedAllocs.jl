# AlignedAllocs.jl
## lightweight cross-platform allocation of aligned memory 
#### Copyright 2025 by Jeffrey Sarnoff. Relased under the MIT License.
----

### exports

- `memalign(item_type, item_count, bytes_of_alignment)`
- `memalign_clear(item_type, item_count, bytes_of_alignment)`

### why it matters

Modern processors retrieve data in memory into fast chip-local caches. At a practical level, the unit of memory retrieval is the cache line.  For most general purpose computing, the size of a cache line is 64 bytes (one cache line holds 64 UInt8s, 32 Int16s, 16 Float32s, or 8 Float64s). When data is stored aligned to this size, its retrieval is simpler. Straddling two cache lines with a single primitive bitstype value incurs costly delays.  

When using SIMD, alignment of 256 bytes (or more, depending on the processor) is critical to getting the throughput one expects from SIMD operations.  Running unaligned data through SIMD slows the processing down significantly.

Julia memory alignment for dense vectors of a numeric bitstype is at least 16 bytes and may be 64 bytes. Which of these alignments obtains depends on the size of the vector. At the time of this writing on a Windows system, 512 Float32s align to 64 bytes while 500 or fewer Float32s may align to 16 bytes. Similarly, 256 Float64s align to 64 bytes while 250 or fewer may align to 16 bytes. A dense vector of 2008 or fewer UInt8s may align to 16 bytes.  These settings are internal to Julia and may change going forward. 

The take away message is that for dense vectors of these sizes, you do not know what allocation alignment holds. If that is not enough uncertainty, the allocation mechanism on Windows differs from the allocation mechanism on 'nix compatible systems.

-----

```
#  vec::DenseVector = memalign(item_type, item_count, nbyte_alignment = 64)
#                              bitstype ,    > 0    ,   2^p where p > 2

element_type      = Float32   # a type T for which isbitstype(T) is true
element_count     = 1024
element_bytes     = sizeof(element_type) * element_count

bytesofalignment  = 64 # bytes

vec = memalign(element_type, element_count, bytesofalignment)
  
vec behaves as a DenseVector with enhanced cache-line performance
vec is unsafe_wrapped contiguous memory from LLVM intrinsic or C/C++ library function
```

----

### also consider
[ArrayAllocators.jl](https://github.com/mkitti/ArrayAllocators.jl) - a type for aligned arrays
  


