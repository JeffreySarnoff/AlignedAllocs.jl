```@meta
CurrentModule = AlignedAllocs
```

# Welcome to AlignedAllocs.jl

AlignedAllocs.jl provides fast, cache aware allocation helpers for Julia arrays that need deterministic alignment. The package wraps platform specific memory allocation primitives in a small, type stable API. The allocated memory is of built-in type Vector{T} where T is the type passed to the allocation function.

*All* allocations use the new Memory infrastructure.

## Highlights
- Portable cache line detection with graceful fallbacks.
- Aligned vectors for POSIX and Windows platforms are garbage collected.
- Zeroed allocations with `memalign_clear` for safe initialization paths.
- Inspect using `alignment` to confirm pointer boundaries.

```@contents
Pages = [
    "guide.md",
    "reference.md",
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

Head over to the [User Guide](guide.md) for practical allocation patterns, or jump straight to the [API Reference](reference.md) when you need detailed signatures.
