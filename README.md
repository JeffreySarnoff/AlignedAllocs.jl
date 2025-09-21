# AlignedAllocs.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JeffreySarnoff.github.io/AlignedAllocs.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JeffreySarnoff.github.io/AlignedAllocs.jl/dev/)
&nbsp;&nbsp;&nbsp;&nbsp;[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

#### All allocations use the new Memory infrastructure.

## Features
- `memalign` and `memalign_clear` for allocating aligned Vector{T}, uninitialized or zeroed.
- `alignment(::AbstractArray)` utility to verify pointer boundaries at runtime.
- Portable cache-line size detection with a safe fallback when probing fails.
- Precompilation of cache-line detection via `PrecompileTools` for fast start-up.

## Installation
```julia
pkg> add AlignedAllocs
```
Julia 1.11 or newer is required.

## Quick Start
```julia
julia> using AlignedAllocs

# Cache-line aligned Float32 buffer
julia> xs = memalign(Float32, 256)
256-element Vector{Float32}:
 0.0
 0.0
 #= output truncated =#

# Explicit alignment with zero-initialisation
julia> ys = memalign_clear(UInt16, 128, 256)

# Inspect alignment guarantee
julia> alignment(ys)
256
```

See the [User Guide](https://JeffreySarnoff.github.io/AlignedAllocs.jl/stable/guide/) for workflow examples and the [API Reference](https://JeffreySarnoff.github.io/AlignedAllocs.jl/stable/reference/) for detailed signatures.

## Alignment Guarantees
- Alignments must be powers of two ≥ 16; invalid inputs throw `ArgumentError`.
- On POSIX systems vectors own the memory returned by `posix_memalign`.
- On Windows vectors register a finalizer that calls `_aligned_free` when the array is collected.
- `memalign_clear` preserves the vector while zeroing memory via `Base.memset`.


## Development
Run the test suite with:
```julia
julia --project=. -e "using Pkg; Pkg.test()"
```
Documentation is built with [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl). See `docs/` for build scripts and source pages.

## License
MIT License © 2025 Jeffrey Sarnoff.
