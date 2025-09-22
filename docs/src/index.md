```@meta
CurrentModule = AlignedAllocs
```

# AlignedAllocs.jl

#### All allocations use the new Memory infrastructure.



AlignedAllocs.jl provides fast, cache alignment aware allocations for Julia vectors, matrices, arrays.
- both {Vector, Matrix, nD Array}{T} and FixedLength{Vector, Matrix, nD Array}{T} are supported.
 
- The package wraps platform specific memory allocation primitives in a small, type stable API.


## What AlignedAllocs.jl brings


#### Julia's Memory type (MemoryRef) is now a cornerstone feature of AlignedAllocs

- Aligned memory obtains
  - backing a Vector{T}
    -  or a Matrix{T} or a Array{T,N}
  - backing a FixedLengthVector{T}
    -  or a FixedLengthMatrix{T} or a FixedSizeArray{T,N}
  
- Aligned memory is obtained
  - either uninitialized or zeroed
  - without offseting
  - without copying
  
- System local cache line size is determined during precompilation
  - this becomes the default alignment

- mutually and successively aligned sequences are available
  - contiguous fixed length vectors are sequentially aligned
  - this works where the sizeof the constituent vector is
    - less than or equal to the alignment of the vector's start
    - if the constituent is larger than the alignment, the alignment is increased

----

## Getting Started
```julia
pkg> add AlignedAllocs

julia> using AlignedAllocs
julia> xs = memalign(Float32, 128)
julia> alignment(xs) >= CACHE_LINE_SIZE  # confirm alignment

julia> ys = memalign_clear(Int32, 64; align=256) 
# 64 Int32s, zeroed, aligned to at least a 256 byte boundry
```
