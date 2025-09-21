```@meta
CurrentModule = AlignedAllocs
```

# API Reference

## Constants
- `CACHE_LINE_SIZE::Int`: L1 cache line size detected at load time, falling back to `FallbackCacheLineSize`.
- `FallbackCacheLineSize::Int`: Static fallback alignment (64 bytes).

## Public Functions
- `alignment(xs::AbstractArray) -> Int`: Largest power-of-two alignment dividing the array's data pointer. Returns `0` for empty arrays.

```@docs
memalign
memalign_clear
```

## Supporting Internals
The following helpers are useful when extending the package to other platforms or writing integration tests.

- `_valid_alignment(align::Integer) -> Bool`
- `check_args(::Type{T}, nitems::Integer, align::Integer)`
- `_memzero!(ptr::Ptr{UInt8}, nbytes::Int)`
- `confirm_alignment(ptr::Ptr, align::Integer)`
- `alloc_error(err)`

```@autodocs
Modules = [AlignedAllocs]
Private = false
```
