using FixedSizeArrays

@inline function _fixed_aligned(::Type{T}, dims::Tuple{Vararg{Integer,N}}, align::Integer, allocator) where {T,N}
    _aligned_construct(T, dims, align, allocator, FixedSizeArrays.new_fixed_size_array)
end

"""
    memalign_fix(::Type{T}, dims...; align=CACHE_LINE_SIZE) where T

Allocate aligned storage for a `FixedSizeArray` of element type `T` with shape `dims`.
The returned array uses `memalign` and preserves the alignment guarantee for the
underlying dense storage.
"""
@inline function memalign_fix(::Type{T}, dims::Tuple{Vararg{Integer,N}}; align::Integer=CACHE_LINE_SIZE) where {T,N}
    _fixed_aligned(T, dims, align, memalign)
end

@inline function memalign_fix(::Type{T}, n::Integer; align::Integer=CACHE_LINE_SIZE) where {T}
    _fixed_aligned(T, (n,), align, memalign)
end

"""
    memalign_clear_fix(::Type{T}, dims...; align=CACHE_LINE_SIZE) where T

Allocate aligned storage for a `FixedSizeArray` of element type `T` with shape `dims`
and initialize all entries to zero.
"""
@inline function memalign_clear_fix(::Type{T}, dims::Tuple{Vararg{Integer,N}}; align::Integer=CACHE_LINE_SIZE) where {T,N}
    _fixed_aligned(T, dims, align, memalign_clear)
end

"""
    memalign_seq(::Type{T}, nvectors, nitems_per_vector; align=CACHE_LINE_SIZE) where T

Allocate `nvectors` fixed-size vectors of type `T`, each with `nitems_per_vector` elements. 
- The start of each vector is aligned to `align` bytes
- the underlying storage is zero-initialized
- Returns an `NTuple{nvectors, FixedSizeVector{T}}
"""
function memalign_seq(::Type{T}, nvectors, nitems_per_vector; align=CACHE_LINE_SIZE) where {T}
    stride = align ÷ sizeof(T)  # elements between start addresses
    storage = memalign_clear_fixed(T, stride * nvectors; align)
    vectors = GC.@preserve storage begin
        baseptr = Base.unsafe_convert(Ptr{T}, storage)
        ntuple(nvectors) do i
            ptr   = baseptr + (i-1) * stride * sizeof(T)
            chunk = Base.unsafe_wrap(Vector{T}, ptr, nitems_per_vector; own = false)
            FixedSizeArrays.new_fixed_size_array(chunk, (nitems_per_vector,))
        end
    end
    vectors
end

# lower level support

@inline function _normalize_dims(dims::Tuple{Vararg{Integer,N}}) where {N}
    N == 0 && throw(ArgumentError("at least one dimension is required"))
    ntuple(Val(N)) do i
        dim = Int(dims[i])
        dim > 0 || throw(ArgumentError("dimension $i ($dim) must be > 0"))
        dim
    end
end

@inline function _checked_length(dims::NTuple{N,Int}) where {N}
    len = Int(1)
    for dim in dims
        len, overflow = Base.Checked.mul_with_overflow(len, dim)
        overflow && throw(OverflowError("dimension product overflowed Int"))
    end
    len
end

@inline function _reshape_aligned(flat::Vector{T}, dims::NTuple{N,Int}) where {T,N}
    reshape(flat, dims)
end

@inline function _aligned_construct(::Type{T}, dims::Tuple{Vararg{Integer,N}}, align::Integer, allocator, builder) where {T,N}
    sdims = _normalize_dims(dims)
    len = _checked_length(sdims)
    buffer = allocator(T, len; align=align)
    return builder(buffer, sdims)
end
#=
# Generic aligned allocation constructor with function barrier.
@inline function _aligned_construct(::Type{T}, dims::Tuple{Vararg{Integer,N}},  align::Integer, allocator::F, builder::G) where {T,N,F,G}
    # Function barrier: separate validation from allocation
    sdims = _normalize_dims(dims)
    len = _checked_length(sdims)
    # Type-stable allocation
    buffer = allocator(T, len; align=Int(align))
    return builder(buffer, sdims)
end
=#

#=

"""
    memaligns(::Type{T}, dims...; align=CACHE_LINE_SIZE) where T

Allocate aligned storage for a multi-dimensional array with element type `T`.
The return value shares storage with a vector allocated via [`memalign`] and
is reshaped to match `dims`.
"""
@inline function memaligns(::Type{T}, dims::Vararg{Integer,N}; align::Integer=CACHE_LINE_SIZE) where {T,N}
    _aligned_construct(T, tuple(dims...), align, memalign, _reshape_aligned)
end
@inline function memaligns(::Type{T}, dims::Tuple{Vararg{Integer,N}}; align::Integer=CACHE_LINE_SIZE) where {T,N}
    _aligned_construct(T, dims, align, memalign, _reshape_aligned)
end

"""
    memaligns_clear(::Type{T}, dims...; align=CACHE_LINE_SIZE) where T

Allocate aligned storage for a multi-dimensional array and zero-initialise the
contents before reshaping to `dims`.
"""
@inline function memaligns_clear(::Type{T}, dims::Vararg{Integer,N}; align::Integer=CACHE_LINE_SIZE) where {T,N}
    _aligned_construct(T, tuple(dims...), align, memalign_clear, _reshape_aligned)
end
@inline function memaligns_clear(::Type{T}, dims::Tuple{Vararg{Integer,N}}; align::Integer=CACHE_LINE_SIZE) where {T,N}
    _aligned_construct(T, dims, align, memalign_clear, _reshape_aligned)
end

=#
