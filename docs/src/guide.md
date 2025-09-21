```@meta
CurrentModule = AlignedAllocs
```

# Guide

## Installation
```julia
pkg> add AlignedAllocs
```
AlignedAllocs.jl targets Julia 1.11 or newer. Installing the package also brings in `PrecompileTools`, which precompiles cache line detection to keep load times minimal.

## Allocating Aligned Buffers
The core allocation API exposes two constructors:

```julia
xs = memalign(Float32, 256)                  # default cache-line alignment
ys = memalign(UInt8, 1024; align=256)        # explicit 256-byte alignment
zs = memalign_clear(UInt16, 128; align=128)  # aligned and zeroed
```

The `align` argument must be a power of two of at least 16 bytes. When omitted the detected `CACHE_LINE_SIZE` is used.

### Verifying Alignment
Use `alignment(xs)` to confirm the pointer boundary:
```julia
@assert alignment(xs) >= CACHE_LINE_SIZE
```

The alignment helper returns the largest power of two dividing the buffer's data pointer. Empty arrays may report `0`.

## Multi-dimensional Arrays

Call `memaligned` to request aligned storage for dense matrices or higher-dimensional arrays without losing ownership semantics.
```julia
az = memaligned(Float32, 32, 8; align=128)
@assert size(az) == (32, 8)
@assert alignment(az) >= 128

bz = memaligned_clear(Float64, (4, 4, 4))
@assert all(iszero, bz)
```

Use tuple arguments or variadic dimensions interchangeably. The result is a reshaped view of the underlying aligned vector, so broadcasting and mutation preserve the pointer guarantee.

## Fixed-Size Arrays

When you need a compile-time shape along with pointer guarantees, combine the package with `FixedSizeArrays.jl` and allocate aligned buffers directly via the fixed helpers.
```julia
using FixedSizeArrays

fs = memalign_fixed(Float32, 4, 4; align=128)
@assert fs isa FixedSizeArrays.FixedSizeMatrix{Float32}
@assert alignment(fs) >= 128

parent_vec = FixedSizeArrays.parent(fs)
@assert pointer(parent_vec) == pointer(fs)
```

Call `memalign_clear_fixed` when you need the storage zeroed before wrapping it. Both constructors accept either variadic dimensions or a single tuple, mirroring the `FixedSizeArrays` API. The `alignment` helper works on the returned arrays because the dense backing store remains available through `parent`.

## Choosing an Alignment
- Keep the default for cache sensitive SIMD code paths.
- Request larger alignments when interfacing with hardware queues or libraries that require explicit boundaries (for example, 256-byte video buffers).
- Oversized alignments can fragment memory; profile before defaulting to the maximum possible value.

## Memory Ownership Semantics
Platform behavior is consistent across releases:
- **Posix**: `memalign` wraps `posix_memalign` and returns an owning `Vector` (`own=true`).
- **Windows**: `memalign` uses `_aligned_malloc`; the returned vector installs a finalizer that calls `_aligned_free`.
- **Zeroed allocations**: `memalign_clear` preserves the vector then clears memory via `Base.memset`.

## Error Handling
| Condition | Exception |
|-----------|-----------|
| Non-positive element count | `ArgumentError` |
| Non-bitstype `T` | `ArgumentError` |
| Invalid alignment | `ArgumentError` |
| Allocation failure | `OutOfMemoryError` |
| Allocator returned misaligned pointer | `ErrorException` |

Wrap allocations in a `try/catch` if you need to recover gracefully:
```julia
try
    buf = memalign(Float32, 1_000_000_000; align=128)
catch err
    @warn "Falling back to smaller buffer" err
    buf = memalign(Float32, 10_000; align=128)
end
```
## Resizing and Mutation
Aligned vectors behave like standard arrays. Resizing may reallocate and thus change the alignment. 
Query `alignment(xs)` again when the exact boundary matters after operations such as `resize!`, `append!`, or `push!`.

## Troubleshooting
- `ArgumentError: Alignment ... must be 2^p where p >= 4` -> use a power of two >= 16 (for example `32`, `64`, `128`).
- `OutOfMemoryError` -> confirm the element count and consider chunked processing.
- Zeroed buffer still shows stale data -> ensure the consumer reads from the returned vector, not a previously cached pointer.

Continue to the [API Reference](reference.md) for function signatures and details.
