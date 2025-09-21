```@meta
CurrentModule = AlignedAllocs
```

# User Guide

## Installation
```julia
pkg> add AlignedAllocs
```
AlignedAllocs.jl targets Julia 1.11 or newer. Installing the package also brings in `PrecompileTools`, which precompiles cache line detection to keep load times minimal.

## Allocating Aligned Buffers
The core API exposes two constructors:

```julia
xs = memalign(Float32, 256)            # default cache-line alignment
ys = memalign(UInt8, 1024, 256)        # explicit 256-byte alignment
zs = memalign_clear(UInt16, 128, 128)  # aligned and zeroed
```

The `align` argument must be a power of two of at least 16 bytes. When omitted the detected `CACHE_LINE_SIZE` is used.

### Verifying Alignment
Use `alignment(xs)` to confirm the pointer boundary:
```julia
ptr_align = alignment(xs)
@assert ptr_align >= CACHE_LINE_SIZE
```

The alignment helper returns the largest power of two dividing the buffer's data pointer. Empty arrays may report `0`.

## Choosing an Alignment
- Keep the default for cache sensitive SIMD code paths.
- Request larger alignments when interfacing with hardware queues or libraries that require explicit boundaries (for example, 256-byte video buffers).
- Oversized alignments can fragment memory; profile before defaulting to the maximum possible value.

## Memory Ownership Semantics
Platform behavior is consistent across releases:
- **POSIX**: `memalign` wraps `posix_memalign` and returns an owning `Vector` (`own=true`).
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
    buf = memalign(Float32, 1_000_000_000, 128)
catch err
    @warn "Falling back to smaller buffer" err
    buf = memalign(Float32, 10_000, 128)
end
```

## Interacting With External Code
Keep a Julia reference alive while passing pointers to C:
```julia
function call_c(ptr, len)
    ccall((:process, libfoo), Cvoid, (Ptr{Float32}, Csize_t), ptr, len)
end

xs = memalign(Float32, 256, 64)
GC.@preserve xs begin
    call_c(pointer(xs), length(xs))
end
```

## Resizing and Mutation
Aligned vectors behave like standard arrays. Resizing may reallocate and thus change the alignment. Query `alignment(xs)` again when the exact boundary matters after operations such as `resize!`, `append!`, or `push!`.

## Troubleshooting
- `ArgumentError: Alignment ... must be 2^p where p >= 4` → use a power of two ≥ 16 (e.g. `32`, `64`, `128`).
- `OutOfMemoryError` → confirm the element count and consider chunked processing.
- Zeroed buffer still shows stale data → ensure the consumer reads from the returned vector, not a previously cached pointer.

Continue to the [API Reference](reference.md) for function signatures and implementation notes.
