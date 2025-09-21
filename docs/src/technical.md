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
  
#### *copy, deepcopy, similar do not preserve alignment*

## Mulitsequential Aligned Vectors

  The best way is to allocate one aligned matrix with memalign_fixed specifying dimensions (4, length) and
  alignment 64, then extract the vectors as slices along one dimension.
  
```julia
  using AlignedAllocs, FixedSizeArrays

  const ALIGN = 64                # byte boundary required
  const LEN   = 16                # elements per vector (tweak as needed)

  # single allocation that is 64-byte aligned
  block = memalign_fixed(Float32, (LEN, 4); align = ALIGN)

  # take the contiguous column slices; each is a FixedSizeVector sharing the buffer
  seq = FixedSizeArrays.slices(block; dims = 2)

  @assert all(x -> alignment(x) >= ALIGN, seq)

  # block is a (LEN × 4) fixed-size matrix whose parent buffer is 64‑byte aligned.
  # FixedSizeArrays.slices (with dims = 2) exposes the four contiguous column vectors without extra allocations,
  # so you get a sequence of four fixed-size vectors backed by the same aligned block. 
  # Adjust LEN or the element type as required.
```

## Interacting With External Code
Keep a Julia reference alive while passing pointers to C:
```julia
function call_c(ptr, len)
    ccall((:process, clibrary), Cvoid, (Ptr{Float32}, Csize_t), ptr, len)
end

T = Float32
nitems = 64
nbytes = nitems * sizeof(T)

xs = memalign(Float32, nitems; align=min(256, nbytes))
GC.@preserve xs begin
    call_c(pointer(xs), length(xs))
end
```
