# AlignedAllocs.jl
## lightweight cross-platform allocation of aligned memory 
#### Copyright 2025 by Jeffrey Sarnoff. Relased under the MIT License.
----

### exports

- `memalign(item_type, item_count, bytes_of_alignment)`
- `memalign_clear(item_type, item_count, bytes_of_alignment)`
  
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
  


