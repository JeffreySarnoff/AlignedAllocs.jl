using Documenter, AlignedAllocs

makedocs(
    modules = [AlignedAllocs],
    sitename = "AlignedAllocs.jl",
    authors = "Jeffrey Sarnoff",
    pages = [
        "Home" => "index.md",
        "User Guide" => "guide.md",
        "API Reference" => "reference.md",
    ]
)

deploydocs(
    repo = "github.com/JeffreySarnoff/AlignedAllocs.jl.git",
    target = "build"
)
