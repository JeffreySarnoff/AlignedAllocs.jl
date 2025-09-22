## Getting Started

the examples do not show the prompt **"julia>"**
(makes trying code simpler)

```julia
using Pkg
Pkg.add("AlignedAllocs")

using AlignedAllocs
xs = memalign(Float32, 128)
alignment(xs) >= CACHE_LINE_SIZE  # confirm alignment

ys = memalign_clear(Int32, 64; align=256) 
typeof(ys) # Vector{Int32}
# confirm that the memory is aligned as requested
alignment(ys) >= 256
```
# 64 Int32s, zeroed, aligned to at least a 256 byte boundary
```
```julia
using AlignedAllocs

xs = memalign_clear_fixed(Int32, 32; align=128)
typeof(xs) # FixedSizeVector{Int32, Vector{Int32}} 
# confirm that the memory is aligned as requested
alignment(xs) >= 128
```

```julia
using AlignedAllocs

nvectors = 4       # this many equilength, isotyped vectors
nitems   = 16      # each vector has this manyitems
T        = Float32 # each item is of this type
align    = 256     # each vector is aligned to (at least) this many bytes

vecs = memalign_vectors(T, nvectors, nitems; align)

length.(vec) # (16, 16, 16, 16)
typeof(vecs) # NTuple{4, FixedSizeVector{Float32, Vector{Float32}}}
v1, v2, v3, v4 = vecs;

typeof(v1) # FixedSizeVector{Float32, Vector{Float32}}
typeof(v2) # FixedSizeVector{Float32, Vector{Float32}}
# ..

alignment.(vecs) .>= align # (true, true, true, true)

# confirm the vectors are equispaced
ptrs = pointer.(vecs);
[Int(ptrs[i+1]-ptrs[i]) for i=1:nvectors-1] # [256, 256, 256]

```


