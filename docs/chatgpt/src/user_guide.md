# User Guide

This guide shows the most common tasks using **AlignedAllocs.jl** with Julia 1.12.

## Installation

This project is a simple module defined by `AlignedAllocs.jl`. If you are developing locally, add the parent directory to your `LOAD_PATH` or use `include`:

```julia
# in the REPL or a script, from the project root
include("AlignedAllocs.jl")
using .AlignedAllocs
```

## Quick start

### Allocate an aligned vector

```jldoctest
julia> include("AlignedAllocs.jl"); using .AlignedAllocs

julia> v = memalign_vec(Float32, 1024; align = CACHE_LINE_SIZE);

julia> alignment(v) ≥ CACHE_LINE_SIZE
true
```

### Allocate and zero‑initialize

```jldoctest
julia> w = memalign_clear_vec(UInt8, 4096; align = 64);

julia> all(w .== 0x00)
true
```

### Fixed‑size aligned arrays

Use `memalign_fix` and `memalign_clear_fix` (note the *fix* suffix).

```jldoctest
julia> include("AlignedAllocs.jl"); using .AlignedAllocs

julia> A = memalign_fix(Float64, 8);  # fixed-size vector length 8

julia> B = memalign_clear_fix(Float32, (4,));  # same as length-4 vector
```

### A sequence of aligned fixed vectors

```jldoctest
julia> include("AlignedAllocs.jl"); using .AlignedAllocs

julia> nv, n = 3, 16
(3, 16)

julia> xs = memalign_seq(Float32, nv, n; align = 64);

julia> length(xs), map(size, xs)
(3, [(16,), (16,), (16,)])
```

Each vector's starting address is aligned to `align` bytes, and the backing storage is zero‑initialized.

### Inspect an array's alignment

```jldoctest
julia> include("AlignedAllocs.jl"); using .AlignedAllocs

julia> v = memalign_vec(Int32, 32; align=64);

julia> alignment(v)  # a power-of-two
64
```

## Platform notes

- **POSIX (Linux/macOS)** paths call `posix_memalign`; errors map to `ArgumentError` or `OutOfMemoryError`.
- **Windows** uses `_aligned_malloc` / `_aligned_free` with a finalizer to free memory.

See the *Technical Guide* for details and safety notes.
