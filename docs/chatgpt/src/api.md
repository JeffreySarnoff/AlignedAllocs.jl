# API Reference

This page is generated from source docstrings where available and augmented with manual signatures.

```@docs
AlignedAllocs
AlignedAllocs.memalign_vec
AlignedAllocs.memalign_clear_vec
AlignedAllocs.memalign_fix
AlignedAllocs.memalign_clear_fix
AlignedAllocs.memalign_seq
AlignedAllocs.alignment
AlignedAllocs.memalign
AlignedAllocs.memalign_clear
```

## Additional details

- Platform-specific internal functions (`memalign_posix`, `memalign_windows`, etc.) are considered internal and may change.
- Helper and validation routines (`_nbytes`, `check_args`, `confirm_alignment`) are not exported but documented in the Technical Guide.
