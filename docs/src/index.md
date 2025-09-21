```@meta
CurrentModule = AlignedAllocs
```

# AlignedAllocs.jl

#### All allocations use the new Memory infrastructure.

AlignedAllocs.jl provides fast, cache aware allocations for Julia vectors that benefit from predetermined alignment. The package wraps platform specific memory allocation primitives in a small, type stable API. The allocated memory is of built-in type Vector{T} where T is the type passed to the allocation function.


## Highlights
- Aligned vectors for POSIX (Mac, Linux) and Windows platforms.
- All allocated vectors are garbage collected.
- Multi-dimensional arrays via `memaligned` and `memaligned_clear`.
- Fixed-size array integration via `memalign_fixed`/`memalign_clear_fixed` and `FixedSizeArrays.jl`.
- Zeroed allocations with `memalign_clear` for safer initialization.
- Inspect using `alignment` to confirm pointer boundaries.
- Portable cache line size detection with graceful fallbacks.

```@contents
Pages = [
    "guide.md",
    "reference.md",
    "technical.md",
]
Depth = 1
```

## Getting Started
```julia
pkg> add AlignedAllocs

julia> using AlignedAllocs
julia> xs = memalign(Float32, 128)
128-element Vector{Float32}:
 0.0
 0.0
 #= output truncated =#

julia> ys = memalign_clear(Float64, 16; align=256) 
# 16 Float64s, zeroed, aligned to 256 (or larger) byte boundry
```
