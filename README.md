# AlignedAllocs.jl
## cross-platform allocation of aligned memory 
##   use as Vector{T}(undef, n) where isbitstype(T)
#### Copyright 2025 by Jeffrey Sarnoff. Relased under the MIT License.
----

There is one exported function: `aaloc(T, nitems, alignment)`.
```
T = Float32
nitmes = 1024
alignment = 64 # bits (sizeof(UInt64) * 8)

myvec = aaloc(Float32, nitems, alignment)

length(myvec) == 64

# << myvec is filled with uninitialized values,
# in this example, nonsensical quasirandom Float32s

myvec ,= zero(Float32)  # make it safer to use

# confirm that the vector is 64 bit aligned
Int(pointer(myvec)) % alignment == 0
```

```
    aalloc(::Type{T}, nitems::Integer, alignto::Integer) where T

__aligned memory allocation__ with finalizer

Allocate memory for a densevector vec = Vector{T}(undef, nitems)
- vec starts at a memory address that is aligned to `alignto` bits
- Int(pointer(vec)) % alignto == 0

works on Unixes (Linux, Apple, Bsd), Windows
```

