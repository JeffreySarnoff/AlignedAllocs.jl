```@meta
CurrentModule = AlignedAllocs
```

# Welcome to AlignedAllocs.jl

AlignedAllocs.jl provides fast, cache aware allocation helpers for Julia arrays that need deterministic alignment. The package wraps platform specific primitives (`posix_memalign`, `_aligned_malloc`, and hardware cache line probes) in a small, type stable API.

## Highlights
- Portable cache line detection with graceful fallbacks.
- Owning aligned vectors for POSIX and Windows platforms.
- Zeroed allocations with `memalign_clear` for safe initialization paths.
- Inspection utilities such as `alignment` to confirm pointer boundaries.

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
```

Head over to the [User Guide](guide.md) for practical allocation patterns, or jump straight to the [API Reference](reference.md) when you need detailed signatures.
