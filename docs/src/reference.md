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

- `is_alignment_valid(align::Integer) -> Bool`
- `check_args(::Type{T}, nitems::Integer, align::Integer)`
- `zeromem(ptr::Ptr{UInt8}, nbytes::Int)`
- `confirm_alignment(ptr::Ptr, align::Integer)`
- `alloc_error(err)`

# Technical Notes

## Interacting With External Code
Keep a Julia reference alive while passing pointers to C:
```julia
function call_c(ptr, len)
    ccall((:process, clibrary), Cvoid, (Ptr{Float32}, Csize_t), ptr, len)
end

T = Float32
nitems = 64
nbytes = nitems * sizeof(T)

xs = memalign(Float32, nitems; align=min(256, nbytes))
GC.@preserve xs begin
    call_c(pointer(xs), length(xs))
end
```
