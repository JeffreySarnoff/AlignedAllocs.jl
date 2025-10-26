# Technical Guide

This document summarizes the design, safety checks, and cross‑platform behavior.

## Alignment detection

A default `CACHE_LINE_SIZE` is chosen at load time:

- macOS: via `sysctlbyname("hw.cachelinesize")`
- Linux/Unix: via `sysconf(_SC_LEVEL1_DCACHE_LINESIZE)`
- Windows: via `GetLogicalProcessorInformationEx`

If detection fails, a conservative fallback of `64` bytes is used. Detection is precompiled via `PrecompileTools.@setup_workload`.

## Core operations

### Aligned vectors

- `memalign_vec(T, n; align=CACHE_LINE_SIZE)` validates:
  - `T` is a `bitstype`
  - `n > 0`
  - `align` is a power of two and ≥ 16
- Backend calls:
  - POSIX: `posix_memalign(&ptr, align, n*sizeof(T))`
  - Windows: `_aligned_malloc(n*sizeof(T), align)` + `_aligned_free` in a `finalizer`
- On success, returns an owning `Vector{T}` with a pointer aligned to `align`.

- `memalign_clear_vec` zero‑fills memory using `Base.memset` on the raw pointer.

### Fixed-size arrays

The `FixedAlignedAllocs.jl` helpers construct fixed-size arrays whose storage originates from `memalign`/`memalign_clear`:

- `_normalize_dims` checks positive dimensions and normalizes to `Int`.
- `_checked_length` uses `Base.Checked.mul_with_overflow` to avoid overflow.
- `memalign_fix` / `memalign_clear_fix` build fixed-size arrays via `FixedSizeArrays.new_fixed_size_array`.

### Sequences of fixed vectors

`memalign_seq(T, nvectors, nitems; align)` allocates one zeroed block large enough for `nvectors` fixed vectors at stride `align/sizeof(T)` elements and returns an `NTuple` of fixed vectors wrapping that storage.

## Safety & correctness

- **Alignment validation**: after allocation, `confirm_alignment(ptr, align)` checks address alignment and frees/reports an error if violated.
- **Error handling**: POSIX error codes map to meaningful Julia exceptions; Windows `NULL` returns map to `OutOfMemoryError`.
- **Ownership**: POSIX uses `unsafe_wrap(...; own=true)`; Windows uses `own=false` and an explicit `finalizer` calling `_aligned_free`.
- **Zeroing**: `memalign_clear_vec` uses `Base.memset` on a preserved pointer (`GC.@preserve`).

## Performance notes

- `_nbytes(T, n)` is a `@generated` function returning a `checked_mul` of `n` and `sizeof(T)` to avoid dynamic dispatch and overflow.
- The simple inline checks and per-platform allocation minimize overhead compared with standard `Vector` allocations, while honoring alignment for SIMD- or DMA‑friendly workloads.

## Compatibility aliases

- `memalign` is an alias of `memalign_vec`.
- `memalign_clear` is an alias of `memalign_clear_vec`.
- The name `memalign_clear_fix` supersedes any prior `memalign_clear_fixed`.
