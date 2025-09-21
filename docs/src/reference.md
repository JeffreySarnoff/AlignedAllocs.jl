```@meta
CurrentModule = AlignedAllocs
```

# Reference

## Constants
- `CACHE_LINE_SIZE::Int`: L1 cache line size detected at load time, falling back to `FallbackCacheLineSize`.
- `FallbackCacheLineSize::Int`: Static fallback alignment (64 bytes).

## Public Functions
- `alignment(xs::AbstractArray) -> Int`: Largest power-of-two alignment dividing the array's data pointer.
- `alignment(xs) Returns `0` for empty arrays.

```@docs
memalign
memalign_clear
```

## Supporting Internals
The following helpers are useful when extending the package to other platforms or writing integration tests.

- `is_alignment_valid(align::Integer) -> Bool`
- `check_args(::Type{T}, nitems::Integer, align::Integer)`
- `zeromem(ptr::Ptr{UInt8}, nbytes::Int)`
- `confirm_alignment(ptr::Ptr, align::Integer)`
- `alloc_error(err)`
