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
# 64 Int32s, zeroed, aligned to at least a 256 byte boundary
```
