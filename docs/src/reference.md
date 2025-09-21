```@meta
CurrentModule = AlignedAllocs
```

# Reference

## Constants
- `CACHE_LINE_SIZE::Int`: L1 cache line size detected at load time, falling back to `FallbackCacheLineSize`.
- `FallbackCacheLineSize::Int`: Static fallback alignment (64 bytes).

## Public Functions
- `alignment(xs::AbstractArray) -> Int`: Largest power-of-two alignment dividing the array's data pointer (returns `0` for empty arrays).

```@docs
memalign
memalign_clear
memaligned
memaligned_clear
memalign_fixed
memalign_clear_fixed
alignment
```

## Supporting Internals
The following helpers are useful when extending the package to other platforms or writing integration tests.

- `is_alignment_valid(align::Integer) -> Bool`
- `check_args(::Type{T}, nitems::Integer, align::Integer)`
- `zeromem(ptr::Ptr{UInt8}, nbytes::Int)`
- `confirm_alignment(ptr::Ptr, align::Integer)`
- `alloc_error(err)`

Continue to the [Technical Notes](technical.md) for information on compatibility and implementation internals.
