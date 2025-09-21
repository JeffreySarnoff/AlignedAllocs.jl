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
using FixedSizeArrays

  const ALIGN = 64          # byte alignment we need
  const LEN   = 16          # elements per fixed vector
  const COUNT = 4           # how many vectors

  # single 64-byte–aligned buffer large enough for all four vectors
  storage = memalign(Float64, LEN * COUNT; align = ALIGN)

  vectors = GC.@preserve storage begin
      baseptr = Base.unsafe_convert(Ptr{Float64}, storage)
      ntuple(COUNT) do i
          ptr   = baseptr + (i-1) * LEN * sizeof(Float64)
          slice = Base.unsafe_wrap(Vector{Float64}, ptr, LEN; own = false)
          FixedSizeArrays.new_fixed_size_array(slice, (LEN,))
      end
  end

  # `vectors` is an NTuple of four FixedSizeVectors that share the aligned buffer.
  # Keep `storage` in scope so the memory remains valid.
  @assert all(vec -> alignment(vec) ≥ ALIGN, vectors)

  #  vectors now holds four contiguous, 64-byte-aligned FixedSizeVectors backed by the single aligned storage allocation.
```
 How can I get 5 contiguous vectors of 4 Float32 values, each aligned to 128 bytes?

 A single aligned buffer plus some padding between slices does the trick. 
 - Each 4×Float32 vector consumes 16 bytes
 - to keep every start address on a 128‑byte boundary
    - we allow STRIDE = 128 ÷ sizeof(Float32) = 32 elements between them.

```julia
  using AlignedAllocs
  using FixedSizeArrays

  const ALIGN  = 128
  const VLEN   = 4                 # elements per fixed vector
  const COUNT  = 5                 # how many vectors
  const STRIDE = ALIGN ÷ sizeof(Float32)  # elements between start addresses

  storage = memalign(Float32, STRIDE * COUNT; align = ALIGN)

  vectors = GC.@preserve storage begin
      baseptr = Base.unsafe_convert(Ptr{Float32}, storage)
      ntuple(COUNT) do i
          ptr   = baseptr + (i-1) * STRIDE * sizeof(Float32)
          chunk = Base.unsafe_wrap(Vector{Float32}, ptr, VLEN; own = false)
          FixedSizeArrays.new_fixed_size_array(chunk, (VLEN,))
      end
  end

  @assert all(v -> alignment(v) ≥ ALIGN, vectors)
```

Above, vectors is an NTuple{5, FixedSizeVector{Float32}}.
- each one shares the same underlying buffer
- each one starting 128 bytes apart
- Keep storage alive for as long as you use the fixed-size views.
  
