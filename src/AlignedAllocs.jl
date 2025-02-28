mmodule AlignedAllocs

export memaligned

# aaloc() error codes
const ENOMEM = Cint(12)  # Out of memory error code
const EINVAL = Cint(22)  # Invalid argument error code

"""
    memalign(::Type{T}, nitems::Integer) where T

__(by default, 8 byte) aligned uninitialized memory allocation__

Allocate memory for a densevector vec = Vector{T}(undef, nitems)
- vec starts at a memory address that is a multiple of 8 bytes

`memalign` works on Unixes (Linux, Apple, Bsd), Windows
""" memalign

@inline funciton memalign(::Type{T}, nitems::Integer) where T
    @static Sys.iswindows() ? amalloc_windows(T, nitems, 64) : amalloc_posix(T, nitems, 64)
end

"""
    memalign(::Type{T}, nitems::Integer, alignto::Integer) where T

__aligned uninitialized memory allocation__ with finalizer

Allocate memory for a densevector vec = Vector{T}(undef, nitems)
- vec starts at a memory address that is a multiple of `alignment` bits
- Int(pointer(vec)) % alignment == 0

- alignment constrains the memory address of start of the vector 
- alignment is bitcount, (alignment ÷ 8 is the alignment in bytes)
- alignment must be a power of 2 and must be >= 16

`amaloc` works on Unixes (Linux, Apple, Bsd), Windows
""" amalloc

@inline function memalign(::Type{T}, nitems::Integer, alignment::Integer) where T
    @static Sys.iswindows() ? memalign_windows(T, nitems, alignment) : memalign_posix(T, nitems, alignment)
end

function memalign_windows(::Type{T}, nitems::Integer, alignment::Integer) where T
    vec = amalloc_windows(T, nitems, alignment)
    vec .= zero(T)
    vec
end
        
function memalign_posix(::Type{T}, nitems::Integer, alignment::Integer) where T
    vec = amalloc_posix(T, nitems, alignment)
    vec .= zero(T)
    vec
end









"""
    acalloc(::Type{T}, nitems::Integer, alignto::Integer) where T

__aligned zeroed memory allocation__ with finalizer

Allocate memory for a densevector vec = zeros(T, nitems)
- vec starts at a memory address that is a multiple of `alignment` bits
- Int(pointer(vec)) % alignment == 0

- alignment constrains the memory address of start of the vector 
- alignment is bitcount, (alignment ÷ 8 is the alignment in bytes)
- alignment must be a power of 2 and must be >= 16

`acaloc` works on Unixes (Linux, Apple, Bsd), Windows
""" acalloc

@inline function acalloc(::Type{T}, nitems::Integer, alignment::Integer) where T
    @static Sys.iswindows() ? acalloc_windows(T, nitems, alignment) : acalloc_posix(T, nitems, alignment)
end

function acalloc_windows(::Type{T}, nitems::Integer, alignment::Integer) where T
    vec = amalloc_windows(T, nitems, alignment)
    vec .= zero(T)
    vec
end
        
function acalloc_posix(::Type{T}, nitems::Integer, alignment::Integer) where T
    vec = amalloc_posix(T, nitems, alignment)
    vec .= zero(T)
    vec
end

# =================================================================================
# =================================================================================
# =================================================================================

@inline function amalloc(T::Type, nitems::Integer, alignment::Integer)
    @static Sys.iswindows() ? amalloc_windows(T, nitems, alignment) : amalloc_posix(T, nitems, alignment)
end

function amalloc_posix(::Type{T}, nitems::Integer, alignment::Integer) where T
    (ispow2(alignment) && alignment >= 16) || 
        throw(ArgumentError("Alignment ($alignment) must be 2^p where p >= 4"))

    bytes_per_item = sizeof(T)
    total_bytes = Base.checked_mul(nitems, bytes_per_item)
        
    local ptr::Ptr{T} = Ptr{T}()

     memref = Ref{Ptr{Cvoid}}(C_NULL)
     ret = ccall( (:posix_memalign, "libc"), Cint,
                  (Ref{Ptr{Cvoid}}, Csize_t, Csize_t),
                  memref, alignment, total_bytes)
    !iszero(ret) && throw(OutOfMemoryError())
    
    ptr = memref[]
    memref = Ref{Ptr{T}}()
    err = ccall((:posix_memalign, "libc"), Cint,
                (Ref{Ptr{T}}, Csize_t, Csize_t),
                memref, alignment, total_bytes)
    !iszero(err) && aaloc_error(err)
    ptr = memref[]
    
    confirm_alignment(ptr, alignment) 
    
    # use the allocated memory as a Vector{T}(undef, nitems)
    vec = unsafe_wrap(Array, Ptr{T}(ptr), nitems; own=true)
    
    finalizer(vec) do x # let the GC to free this allocated memory
        @GC.preserve x ccall((:free, "libc"), Cvoid, (Ptr{T},), ptr)
    end
    
    return vec
end

function amalloc_windows(::Type{T}, nitems::Integer, alignment::Integer) where T
    (ispow2(alignment) && alignment >= 16) || 
        throw(ArgumentError("Alignment ($alignment) must be 2^p where p >= 4"))
    
    item_bytes = sizeof(T)    
    total_bytes = Base.checked_mul(nitems, item_bytes)
        
    local ptr::Ptr{T} = Ptr{T}()
    
    ptr = ccall((:_aligned_malloc, "msvcrt"), Ptr{T},
                (Csize_t, Csize_t), total_bytes, alignment)        
    (ptr == C_NULL) && aaloc_error(ENOMEM)

    confirm_alignment(ptr, alignment) 
    
    # use the allocated memory as a Vector{T}(undef, nitems)
    vec = unsafe_wrap(Array, Ptr{T}(ptr), nitems; own=true)
    
    # allow the GC to free the allocated memory
    finalizer(vec) do x
        @GC.preserve x ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{T},), ptr)
    end
    
    return vec
end

# error handling

function confirm_alignment(ptr::Ptr, alignment::Integer)
    if UInt(ptr) % alignment != 0
        if Sys.iswindows()
            ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{Cvoid},), ptr)
        else
            ccall((:free, "libc"), Cvoid, (Ptr{Cvoid},), ptr)
        end

        errmsg = "aligned memory allocation failed: returned address $(UInt(ptr)) is not aligned to $(alignment) bytes"
        throw(ErrorException(errmsg))
    end
end

function aalloc_error(err)
    iszero(err) && return nothing
    
    if err == EINVAL
        throw(ArgumentError("Invalid alignment: must be power of 2 and multiple of $ptr_size"))
    else
        throw(OutOfMemoryError())
    end
end

end  # AlignedAlloc

