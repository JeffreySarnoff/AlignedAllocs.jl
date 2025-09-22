```@meta
CurrentModule = AlignedAllocs
```

# AlignedAllocs.jl

#### All allocations use the new Memory infrastructure.



AlignedAllocs.jl provides fast, cache alignment aware allocations for Julia vectors, matrices, arrays.
- {Vector, Matrix, nD Array}{T} are supported
- FixedLength{Vector, Matrix, nD Array}{T} are supported
- The package wraps platform specific memory allocation primitives
  - in a consistent, small, coherent and type stable API.


## What AlignedAllocs.jl brings


#### Julia's Memory type (MemoryRef) is now a cornerstone feature of AlignedAllocs

- Aligned memory is provided
  - backing a Vector{T} or an Array{T,N}
  - backing a FixedSizeVector{T} or a FixedSizeArray{T,N}
  
- Aligned memory is obtained
  - either uninitialized or zeroed
  - without offsets into another memory object
  - without copying from another memory source
  
- System local cache line size is determined during precompilation
  - this becomes the default alignment

- mutually and successively aligned sequences are available
  - contiguous fixed length vectors are sequentially aligned
  - this works where the sizeof the constituent vector is
    - less than or equal to the alignment of the vector's start
    - if the constituent is larger than the alignment, the alignment is increased

