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
  
**copy(), deepcopy(), similar() do *not* preserve alignment**

----

## Mulitsequential Aligned Vectors

```
vectors = memalign_vectors(T, nvectors, nitems_per_vector; align=<alignment of every vector>)
```
 
Above, vectors is an NTuple{nvectors, FixedSizeVector{T}}.
- each one shares the same underlying buffer
- each one starting 128 bytes apart
- Keep storage alive for as long as you use the fixed-size views.
  
