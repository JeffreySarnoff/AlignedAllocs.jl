using FixedSizeArrays

const DEFAULT_FIXED_ALIGNMENT = CACHE_LINE_SIZE

@inline function _fixed_aligned(::Type{T}, dims::Tuple{Vararg{Integer,N}}, align::Integer, allocator) where {T,N}
    _aligned_construct(T, dims, align, allocator, FixedSizeArrays.new_fixed_size_array)
end

"""
    memalign_fixed(::Type{T}, dims...; align=CACHE_LINE_SIZE) where T

Allocate aligned storage for a `FixedSizeArray` of element type `T` with shape `dims`.
The returned array uses `memalign` and preserves the alignment guarantee for the
underlying dense storage.
"""
@inline function memalign_fixed(::Type{T}, dims::Vararg{Integer,N}; align::Integer=DEFAULT_FIXED_ALIGNMENT) where {T,N}
    memalign_fixed(T, tuple(dims...); align=align)
end
@inline function memalign_fixed(::Type{T}, dims::Tuple{Vararg{Integer,N}}; align::Integer=DEFAULT_FIXED_ALIGNMENT) where {T,N}
    _fixed_aligned(T, dims, align, memalign)
end

"""
    memalign_clear_fixed(::Type{T}, dims...; align=CACHE_LINE_SIZE) where T

Allocate aligned storage for a `FixedSizeArray` of element type `T` with shape `dims`
and initialize all entries to zero.
"""
@inline function memalign_clear_fixed(::Type{T}, dims::Vararg{Integer,N}; align::Integer=DEFAULT_FIXED_ALIGNMENT) where {T,N}
    memalign_clear_fixed(T, tuple(dims...); align=align)
end
@inline function memalign_clear_fixed(::Type{T}, dims::Tuple{Vararg{Integer,N}}; align::Integer=DEFAULT_FIXED_ALIGNMENT) where {T,N}
    _fixed_aligned(T, dims, align, memalign_clear)
end