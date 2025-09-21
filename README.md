# AlignedAllocs.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JeffreySarnoff.github.io/AlignedAllocs.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JeffreySarnoff.github.io/AlignedAllocs.jl/dev/)
&nbsp;&nbsp;&nbsp;&nbsp;[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

#### All allocations use the new Memory infrastructure.

## Features
- `memalign` and `memalign_clear` allocate aligned `Vector{T}` storage, either uninitialised or zeroed.
- `memaligned` and `memaligned_clear` reshape aligned buffers into multi-dimensional arrays without copying.
- `memalign_fixed` and `memalign_clear_fixed` build aligned `FixedSizeArrays.jl` containers directly.
- `alignment(::AbstractArray)` reports the effective pointer alignment at runtime.
- Cache-line detection with a safe fallback keeps defaults portable across platforms.
- Precompilation via `PrecompileTools` minimises package load time.


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

# Multi-dimensional array with aligned storage
julia> az = memaligned(Float32, 32, 8; align=128)
32x8 Matrix{Float32}:
 0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0
 #= output truncated =#

# Fixed-size array backed by aligned storage
julia> using FixedSizeArrays
julia> fs = memalign_fixed(Float32, 16, 4; align=128)
16x4 FixedSizeArrays.FixedSizeMatrix{Float32}:
 0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0
 #= output truncated =#

# Inspect alignment guarantee
julia> alignment(az)
128
```


See the [User Guide](https://JeffreySarnoff.github.io/AlignedAllocs.jl/stable/guide/) for workflow examples and the [API Reference](https://JeffreySarnoff.github.io/AlignedAllocs.jl/stable/reference/) for detailed signatures.

## Alignment Guarantees
- Alignments must be powers of two >= 16 bytes; invalid inputs throw `ArgumentError`.
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
MIT License (c) 2025 Jeffrey Sarnoff.
