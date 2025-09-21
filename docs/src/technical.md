```@meta
CurrentModule = AlignedAllocs
```

# Tech Notes

## All Vector methods are supported

- length
- sort!, unique!, reverse!
- push!, pushfirst!, pop!, popfirst!, popat!
- append!, prepend!
- insert!, deleteat!, keepat!, splice!, replace!
- empty!, resize!
  
**copy(), deepcopy(), similar() do *not* preserve alignment**

----

## Mulitsequential Aligned Vectors

### when the sequence of vectors fills the memory space

use memalign\_clear\_fixed to allocate a fixed-size matrix:
  - block is a (LEN × 4) fixed-size matrix whose parent buffer is 64‑byte aligned.
  - FixedSizeArray[:,1],..,FixedSizeArray[:,4] exposes the four contiguous column vectors without extra allocations,
  - so you get a sequence of four fixed-size vectors backed by the same aligned block. 
  - Adjust LEN or the element type as required.


### when the sequence of vectors partially fill the memory space

  The best way is to allocate one aligned matrix with memalign_fixed specifying dimensions (4, length) and
  alignment 64, then extract the vectors as slices along one dimension.

```julia
  using AlignedAllocs
  using FixedSizeArrays

  T = Float32
  vector_align  = 128          # byte alignment required for each vector  
  nitems   = 4                 # elements per fixed vector
  nvectors  = 5                 # how many vectors
  stride = vector_align ÷ sizeof(T)  # elements between start addresses

  storage = memalign_clear_fixed(T, stride * nvectors; align = vector_align)

  vectors = GC.@preserve storage begin
      baseptr = Base.unsafe_convert(Ptr{T}, storage)
      ntuple(nvectors) do i
          ptr   = baseptr + (i-1) * stride * sizeof(T)
          chunk = Base.unsafe_wrap(Vector{T}, ptr, nitems; own = false)
          FixedSizeArrays.new_fixed_size_array(chunk, (nitems,))
      end
  end

  @assert all(v -> alignment(v) ≥ vector_align, vectors)
```

Above, vectors is an NTuple{nvectors, FixedSizeVector{T}}.
- each one shares the same underlying buffer
- each one starting 128 bytes apart
- Keep storage alive for as long as you use the fixed-size views.
  
