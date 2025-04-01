# AlignedAllocs.jl
## lightweight cross-platform allocation of aligned memory 
#### Copyright 2025 by Jeffrey Sarnoff. Relased under the MIT License.
----
![image](https://github.com/user-attachments/assets/407b877f-84aa-47bc-8756-e049770a846b)

----

### exports

- `memalign(item_type, item_count, byte_alignment)`
  - returns an uninitialized DenseVector{T} of length `item_count`
  - T is a bitstype
  
- `memalign_clear(item_type, item_count, byte_alignment)`
  - returns a zeroed DenseVector{T} of length `item_count`
  - T is a bitstype (ensure `zero(T)` exists)

- `byte_alignment` defaults to the local processor's cache-line size

### why it matters

Modern processors retrieve data in memory into fast chip-local caches. In practice, the unit of memory retrieval is the cache line.  For most general purpose computing, the size of (the Level 1) cache line is 64 bytes (one cache line holds 64 UInt8s, 32 Int16s, 16 Float32s, or 8 Float64s). When data is stored aligned to this size, its retrieval is simpler. Straddling two cache lines with a single primitive bitstype value incurs costly delays.  

When using SIMD, alignment of 256 bytes (or more, depending on the processor) is critical to getting the throughput one expects from SIMD operations.  Running unaligned data through SIMD slows the processing down significantly.

Julia memory alignment for dense vectors of numeric bitstypes is at least 16 bytes and may be 64 bytes. Which of these alignments obtains depends :). At the time of this writing on a Windows system, 512 Float32s align to 64 bytes while 500 or fewer Float32s may align to 16 bytes. Similarly, 256 Float64s align to 64 bytes while 250 or fewer may align to 16 bytes. Without this module, a dense vector of 2008 or fewer UInt8s may align to 16 bytes.  If that is not enough uncertainty, the allocation mechanism on Windows differs from the allocation mechanism on Apple and 'nix compatible systems. The specifics are internal to Julia and may change going forward.

The take away message is that for dense vectors generally, you do not know what allocation alignment will hold with certainty.

There is some good news. GPU allocations are written to work well with the GPU.

-----

```
function encodings(bitwidth, typ=UInt16)
    n = 2^bitwidth
    codes = memalign_clear(typ, n)
    codes[:] = collect(map(typ, 0:(n-1)))
    codes
end
```

```
#  vec::DenseVector = memalign(item_type, item_count, byte_alignment = 64)
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
  

----
### Thank you

- Stephan Karpinski
- Gabriel Baraldi
- Diogo Netto
- Bradley
- chakravala
- Jakob Nybo Nissen
- Sinh Trung


