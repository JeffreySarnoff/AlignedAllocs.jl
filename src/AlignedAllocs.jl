module AlignedAllocs

<<<<<<< HEAD
export memalign, memalign_zeros
=======
export memalign, memalign_clear
>>>>>>> origin/main

# allocation error codes
const ENOMEM = Cint(12)  # Out of memory error code
const EINVAL = Cint(22)  # Invalid argument error code

"""
<<<<<<< HEAD
    memalign(::Type{T}, nitems::Integer, alignment=64) where T
=======
    memalign(::Type{T}, nitems::Integer, alignment::Integer=64) where T
>>>>>>> origin/main

__aligned uninitialized memory allocation__

Allocate memory for a densevector vec = Vector{T}(undef, nitems)
<<<<<<< HEAD
- vec starts at a memory address that is a multiple of alignment bytes
=======
- vec starts at a memory address that is a multiple of `alignment` bytes
- Int(pointer(vec)) % alignment == 0

- alignment constrains the memory address of start of the vector 
- alignment is bitcount, (alignment * 8 is the alignment in bits)
- alignment must be a power of 2 and must be >= 16
>>>>>>> origin/main

`memalign` works on Unixes (Linux, Apple, Bsd), Windows
""" memalign

@inline function memalign(::Type{T}, nitems::Integer, alignment::Integer=64) where T
<<<<<<< HEAD
    @static Sys.iswindows() ? amalloc_windows(T, nitems, alignment) : amalloc_posix(T, nitems, alignment)
end

"""
    memalign_zeros(::Type{T}, nitems::Integer, alignment=64) where T
=======
    @static Sys.iswindows() ? memalign_windows(T, nitems, alignment) : memalign_posix(T, nitems, alignment)
end

"""
    memalign_clear(::Type{T}, nitems::Integer, alignment=64) where T
>>>>>>> origin/main

__aligned zeroed memory allocation__

Allocate memory for a densevector vec = zeros(T, nitems)
- vec starts at a memory address that is a multiple of alignment bytes

<<<<<<< HEAD
`memalign_zeros` works on Unixes (Linux, Apple, Bsd), Windows
""" memalign_zeros

@inline function memalign_zeros(::Type{T}, nitems::Integer, alignment::Integer=64) where T
    @static Sys.iswindows() ? acalloc_windows(T, nitems, alignment) : acalloc_posix(T, nitems, alignment)
end

@inline function amalloc_windows(::Type{T}, nitems::Integer, alignment::Integer) where T
    vec = memalign_windows(T, nitems, alignment)
    vec
end
        
@inline function amalloc_posix(::Type{T}, nitems::Integer, alignment::Integer) where T
    vec = memalign_posix(T, nitems, alignment)
    vec
end

@inline function acalloc_windows(::Type{T}, nitems::Integer, alignment::Integer) where T
=======
`memalign_clear` works on Unixes (Linux, Apple, Bsd), Windows
""" memalign_clear

@inline function memalign_clear(::Type{T}, nitems::Integer, alignment::Integer=64) where T
    @static Sys.iswindows() ? memalign_clear_windows(T, nitems, alignment) : 
                              memalign_clear_posix(T, nitems, alignment)
end

@inline function memalign_clear_windows(::Type{T}, nitems::Integer, alignment::Integer) where T
>>>>>>> origin/main
    vec = memalign_windows(T, nitems, alignment)
    vec .= zero(T)
    vec
end
        
<<<<<<< HEAD
@inline function acalloc_posix(::Type{T}, nitems::Integer, alignment::Integer) where T
=======
@inline function memalign_clear_posix(::Type{T}, nitems::Integer, alignment::Integer) where T
>>>>>>> origin/main
    vec = memalign_posix(T, nitems, alignment)
    vec .= zero(T)
    vec
end

# =================================================================================

<<<<<<< HEAD
function amalloc_posix(::Type{T}, nitems::Integer, alignment::Integer) where T
=======
function memalign_posix(::Type{T}, nitems::Integer, alignment::Integer) where T
>>>>>>> origin/main
    (ispow2(alignment) && alignment >= 16) || 
        throw(ArgumentError("Alignment ($alignment) must be 2^p where p >= 4"))

    bytes_per_item = sizeof(T)
    total_bytes = Base.checked_mul(nitems, bytes_per_item)

    local ptr::Ptr{T} = Ptr{T}()

    memref = Ref{Ptr{Cvoid}}(C_NULL)
    ret = ccall((:posix_memalign, "libc"), Cint,
                (Ref{Ptr{Cvoid}}, Csize_t, Csize_t),
                 memref, alignment, total_bytes)
    !iszero(ret) && alloc_error(ret)
    
    ptr = memref[]
    confirm_alignment(ptr, alignment) 
    
    # use the allocated memory as a Vector{T}(undef, nitems)
    vec = @GC.preserve ptr unsafe_wrap(Array, Ptr{T}(ptr), nitems; own=true)
    
    return vec
end

function memalign_windows(::Type{T}, nitems::Integer, alignment::Integer) where T
    (ispow2(alignment) && alignment >= 16) || 
        throw(ArgumentError("Alignment ($alignment) must be 2^p where p >= 4"))
    
    item_bytes = sizeof(T)    
    total_bytes = Base.checked_mul(nitems, item_bytes)
        
    local ptr::Ptr{T} = Ptr{T}()
    
    ptr = ccall((:_aligned_malloc, "msvcrt"), Ptr{T},
                (Csize_t, Csize_t), total_bytes, alignment)        
    (ptr == C_NULL) && alloc_error(ENOMEM)

    confirm_alignment(ptr, alignment) 
    
    # use the allocated memory as a Vector{T}(undef, nitems)
    vec = @GC.preserve ptr unsafe_wrap(Array, Ptr{T}(ptr), nitems; own=false)
    
    # allow the GC to free the allocated memory
    finalizer(vec) do _
        @GC.preserve ptr ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{T},), ptr)
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

function alloc_error(err)
    iszero(err) && return nothing
    
    if err == EINVAL
        throw(ArgumentError("Invalid alignment: must be power of 2 and multiple of $ptr_size"))
    else
        throw(OutOfMemoryError())
    end
end

end  # AlignedAllocs


