```@meta
CurrentModule = AlignedAllocs
```

# Tech Notes

## All Vector methods are supported

- length
- sort!, unique!, reverse!
- push!, pushfirst!, pop!, popfirst!, popat!
- append!, prepend!
- insert!, deleteat!, keepat!, splice!, replace!
- empty!, resize!
  
#### *copy, deepcopy, similar do not preserve alignment*

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
