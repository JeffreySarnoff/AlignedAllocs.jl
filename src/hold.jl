module AlignedAllocs

export memalign, memalign_clear, alignment

using Base: Libc
using PrecompileTools

#=
> - The existing allocators already hand back a Vector, so the raw pointer is untouched. To switch that to Base’s
  managed pointer wrappers you can replace the unsafe_wrap(Array, …) calls in memalign_posix and memalign_windows (src/
  AlignedAllocs.jl:35-71) with unsafe_wrap(Base.Memory{T}, …). That produces a GenericMemory{:not_atomic,T,Core.CPU}
  instance, i.e. Base.Memory{T}, and no copy occurs.
  - POSIX path → unsafe_wrap(Base.Memory{T}, Ptr{T}(ptr), nitems; own=true) lets Julia call free when the object dies.
  Windows path → use own=false and keep the finalizer you already install to invoke _aligned_free, just switch the
  closure to call pointer(mem) (or unsafe_convert(Ptr{T}, mem)) instead of pointer(v).
  - If you want to expose a reference wrapper instead, return Base.memoryref(mem) from a helper; it yields
  Base.MemoryRef{T} without touching the payload and still points at the aligned allocation.
  - These types are currently internal to Base and labelled experimental in the manual, so baking them into the API
  would tie you to Julia ≥1.11 and risk breakage if their semantics change. Offering them as optional constructors
  (memalign_memory, memalign_memoryref) alongside the existing Vector API is the least disruptive way to experiment.
=#

# define CACHE_LINE_SIZE as a module scoped constant
include("precompilation.jl")

if !(@isdefined CACHE_LINE_SIZE)
   if @isdefined detect_cache_line_size
       const CACHE_LINE_SIZE = detect_cache_line_size()
   else
       const CACHE_LINE_SIZE = FallbackCacheLineSize
   end
end

# allocation error codes
const ENOMEM = Cint(12)  # Out of memory error code
const EINVAL = Cint(22)  # Invalid argument error code

"""
    memalign(::Type{T}, nitems::Integer, align::Integer=64) where T

__aligned uninitialized memory allocation__

Allocate memory for a densevector vec = Vector{T}(undef, nitems)
- vec starts at a memory address that is a multiple of `align` bytes
- Int(pointer(vec)) % align == 0

- align constrains the memory address of start of the vector 
- align is bitcount, (align * 8 is the alignment in bits)
- align must be a power of 2 and must be >= 16

`memalign` works on Unixes (Linux, Apple, Bsd), Windows
""" memalign

@inline function memalign(::Type{T}, nitems::Integer, align::Integer=CACHE_LINE_SIZE) where T
    @static Sys.iswindows() ? memalign_windows(T, nitems, align) : memalign_posix(T, nitems, align)
end

"""
    memalign_clear(::Type{T}, nitems::Integer, align=64) where T

__aligned zeroed memory allocation__

Allocate memory for a densevector vec = zeros(T, nitems)
- vec starts at a memory address that is a multiple of align bytes

`memalign_clear` works on Unixes (Linux, Apple, Bsd), Windows
""" memalign_clear

@inline function memalign_clear(::Type{T}, nitems::Integer, align::Integer=CACHE_LINE_SIZE) where T
    @static Sys.iswindows() ? memalign_clear_windows(T, nitems, align) : 
                              memalign_clear_posix(T, nitems, align)
end

@inline function memalign_clear_windows(::Type{T}, nitems::Integer, align::Integer) where T
    vect = memalign_windows(T, nitems, align)
    fill!(vect, zero(T))
    vect
end
        
@inline function memalign_clear_posix(::Type{T}, nitems::Integer, align::Integer) where T
    vect = memalign_posix(T, nitems, align)
    fill!(vect, zero(T))
    vect
end

# =================================================================================

function memalign_posix(::Type{T}, nitems::Integer, align::Integer) where T
    check_args(T, nitems, align)

    total_bytes = Base.checked_mul(nitems, sizeof(T))

    local ptr::Ptr{T} = Ptr{T}()
    memref = Ref{Ptr{Cvoid}}(C_NULL)
    ret = ccall((:posix_memalign), Cint,
                (Ref{Ptr{Cvoid}}, Csize_t, Csize_t),
                 memref, align, total_bytes)
    !iszero(ret) && alloc_error(ret)
    
    ptr = memref[]
    confirm_alignment(ptr, align) 
    
    # use the allocated memory as a Vector{T}(undef, nitems)
    vect = @GC.preserve ptr unsafe_wrap(Array, Ptr{T}(ptr), nitems; own=true)
    
    return vect
end

function memalign_windows(::Type{T}, nitems::Integer, align::Integer) where T
    check_args(T, nitems, align)
    
    total_bytes = Base.checked_mul(nitems, sizeof(T))
        
    local ptr::Ptr{T} = Ptr{T}()    
    ptr = ccall((:_aligned_malloc, "msvcrt"), Ptr{T},
                (Csize_t, Csize_t), total_bytes, align)        
    (ptr == C_NULL) && alloc_error(ENOMEM)

    confirm_alignment(ptr, align) 
    
    # use the allocated memory as a Vector{T}(undef, nitems)
    vect = @GC.preserve ptr unsafe_wrap(Array, Ptr{T}(ptr), nitems; own=false)
    
    # allow the GC to free the allocated memory
    @static if VERSION > v"1.11-"
        finalizer(getfield(vect, :ref).mem) do m
            @GC.preserve ptr ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{T},), pointer(m))
        end
    else
        finalizer(vect) do v
            @GC.preserve ptr ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{T},), pointer(v))
        end
    end    

    return vect
end

function memory_memalign_windows(::Type{T}, nitems::Integer, align::Integer) where T
    check_args(T, nitems, align)
    
    total_bytes = Base.checked_mul(nitems, sizeof(T))
        
    local ptr::Ptr{T} = Ptr{T}()    
    ptr = ccall((:_aligned_malloc, "msvcrt"), Ptr{T},
                (Csize_t, Csize_t), total_bytes, align)        
    (ptr == C_NULL) && alloc_error(ENOMEM)

    confirm_alignment(ptr, align) 
    
    #  Windows path → use own=false and keep the finalizer you already install to invoke _aligned_free, just switch the
    #  closure to call pointer(mem) (or unsafe_convert(Ptr{T}, mem)) instead of pointer(v).
   
    # use the allocated memory as a Vector{T}(undef, nitems)
    vect = @GC.preserve ptr unsafe_wrap(Array, Ptr{T}(ptr), nitems; own=false)
    
    # allow the GC to free the allocated memory
    @static if VERSION > v"1.11-"
        finalizer(getfield(vect, :ref).mem) do m
            @GC.preserve ptr ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{T},), pointer(m))
        end
    else
        finalizer(vect) do v
            @GC.preserve ptr ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{T},), pointer(v))
        end
    end    

    return vect
end
# =================================================================================

# error handling

function check_args(::Type{T}, nitems, align) where T
    isbitstype(T) || 
    throw(ArgumentError("element_type ($T) must be a `bitstype`"))

    nitems > 0 || 
    throw(ArgumentError("element_count ($nitems) must be > 0"))

    (ispow2(align) && align >= 16) || 
    throw(ArgumentError("Alignment ($align) must be 2^p where p >= 4"))
end

function confirm_alignment(ptr::Ptr, align::Integer)
    if UInt(ptr) % align != 0
        if Sys.iswindows()
            ccall((:_aligned_free, "msvcrt"), Cvoid, (Ptr{Cvoid},), ptr)
        else
            ccall((:free, "Libc"), Cvoid, (Ptr{Cvoid},), ptr)
        end

        errmsg = "aligned memory allocation failed: returned address $(UInt(ptr)) is not aligned to $(align) bytes"
        throw(ErrorException(errmsg))
    end
end

function alloc_error(err)
    iszero(err) && return nothing
    
    if err == EINVAL
        throw(ArgumentError("Invalid alignment: must be power of 2 and multiple of $ptr_size"))
    elseif err == ENOMEM
        throw(OutOfMemoryError())
    else
        throw(ErrorException("Allocation error: $err"))
    end
end

# alignment checking

alignment(xs::AbstractArray) = 2^trailing_zeros(UInt64(pointer(xs)))
    
end  # AlignedAllocs


