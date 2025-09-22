# FixedAlignedAllocs.jl
# Included from AlignedAllocs.jl - assumes parent module context

using FixedSizeArrays

# Type-stable constant
const DEFAULT_FIXED_ALIGNMENT::Int = CACHE_LINE_SIZE

"""
Internal constructor for fixed-size aligned arrays.
Type-stable with function barrier pattern.
"""
@inline function _fixed_aligned(::Type{T}, dims::Tuple{Vararg{Integer,N}}, 
                               align::Integer, allocator::F) where {T,N,F}
    _aligned_construct(T, dims, align, allocator, FixedSizeArrays.new_fixed_size_array)
end

"""
    memalign_fixed(::Type{T}, dims...; align=CACHE_LINE_SIZE) where T

Allocate aligned storage for a `FixedSizeArray` of element type `T` with shape `dims`.
Preserves alignment guarantee for underlying dense storage.

Performance: Zero-overhead abstraction over aligned allocation.
"""
@inline function memalign_fixed(::Type{T}, dims::Vararg{Integer,N}; 
                               align::Integer=DEFAULT_FIXED_ALIGNMENT) where {T,N}
    memalign_fixed(T, dims; align=align)
end

@inline function memalign_fixed(::Type{T}, dims::Tuple{Vararg{Integer,N}}; 
                               align::Integer=DEFAULT_FIXED_ALIGNMENT) where {T,N}
    _fixed_aligned(T, dims, align, memalign)
end

"""
    memalign_clear_fixed(::Type{T}, dims...; align=CACHE_LINE_SIZE) where T

Allocate aligned storage for a `FixedSizeArray` with zero initialization.

Performance: Combined allocation and initialization for better cache usage.
"""
@inline function memalign_clear_fixed(::Type{T}, dims::Vararg{Integer,N}; 
                                     align::Integer=DEFAULT_FIXED_ALIGNMENT) where {T,N}
    memalign_clear_fixed(T, dims; align=align)
end

@inline function memalign_clear_fixed(::Type{T}, dims::Tuple{Vararg{Integer,N}}; 
                                     align::Integer=DEFAULT_FIXED_ALIGNMENT) where {T,N}
    _fixed_aligned(T, dims, align, memalign_clear)
end

"""
    memalign_vectors(::Type{T}, nvectors, nitems_per_vector; align=CACHE_LINE_SIZE) where T

Allocate `nvectors` fixed-size vectors with aligned starts.

Performance optimizations:
- Each vector start is cache-line aligned
- Underlying storage is zero-initialized
- Returns compile-time sized tuple

# Returns
- `NTuple{nvectors, FixedSizeVector{T}}` with aligned storage
"""
function memalign_vectors(::Type{T}, nvectors::Integer, nitems_per_vector::Integer; 
                         align::Integer=CACHE_LINE_SIZE) where {T}
    # Type-stable computations
    nvectors_int = Int(nvectors)
    nitems_int = Int(nitems_per_vector)
    align_int = Int(align)
    
    # Validate inputs
    nvectors_int > 0 || throw(ArgumentError("nvectors must be > 0"))
    nitems_int > 0 || throw(ArgumentError("nitems_per_vector must be > 0"))
    
    # Calculate stride ensuring alignment
    stride = cld(align_int, sizeof(T))  # Elements between starts
    
    # Ensure stride is sufficient for data
    stride = max(stride, nitems_int)
    
    # Allocate backing storage
    total_elements = stride * nvectors_int
    storage = memalign_clear_fixed(T, total_elements; align=align_int)
    
    # Create vectors with proper lifetime management
    vectors = GC.@preserve storage begin
        baseptr = Base.unsafe_convert(Ptr{T}, storage)
        
        # Use ntuple for compile-time optimization when possible
        if nvectors_int ≤ 10  # Small tuple - fully unroll
            ntuple(Val(nvectors_int)) do i
                @inbounds begin
                    offset = (i - 1) * stride
                    ptr = baseptr + offset * sizeof(T)
                    chunk = Base.unsafe_wrap(Vector{T}, ptr, nitems_int; own=false)
                    FixedSizeArrays.new_fixed_size_array(chunk, (nitems_int,))
                end
            end
        else  # Large tuple - use regular ntuple
            ntuple(nvectors_int) do i
                @inbounds begin
                    offset = (i - 1) * stride
                    ptr = baseptr + offset * sizeof(T)
                    chunk = Base.unsafe_wrap(Vector{T}, ptr, nitems_int; own=false)
                    FixedSizeArrays.new_fixed_size_array(chunk, (nitems_int,))
                end
            end
        end
    end
    
    return vectors
end

# Precompilation hints for fixed arrays
@setup_workload begin
    @compile_workload begin
        # Common fixed array patterns
        f1 = memalign_fixed(Float64, 64)
        f2 = memalign_clear_fixed(Float32, 8, 8)
        
        # Vector allocation pattern
        vecs = memalign_vectors(Float64, 4, 16)
    end
end
