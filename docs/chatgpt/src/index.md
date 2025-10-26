# AlignedAllocs.jl

**AlignedAllocs.jl** provides fast, low-level *aligned* memory allocation utilities for Julia 1.12+.

- Cross‑platform aligned allocations for `Vector{T}` via `memalign_vec` / `memalign_clear_vec` (exports `memalign` / `memalign_clear` as compatibility aliases).
- Fixed-size, aligned arrays using **FixedSizeArrays.jl** via `memalign_fix` and `memalign_clear_fix`.
- Sequences of equal-length fixed vectors with guaranteed per-vector alignment using `memalign_seq`.
- Utility `alignment(::AbstractArray)` returns the power-of-two alignment of an array's data pointer.

This documentation set follows Julia and Documenter.jl best practices and is organized into:

- **User Guide** — practical, copy‑pasteable examples.
- **Technical Guide** — architecture, design choices, safety notes.
- **API** — complete reference generated from docstrings and source.

> **Naming note**: All references here use `memalign_clear_fix` (with a trailing `fix`). If you saw `memalign_clear_fixed` elsewhere, that name has been retired in favor of `memalign_clear_fix`.
