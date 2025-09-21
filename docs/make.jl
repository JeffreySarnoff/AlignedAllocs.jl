import Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

using Documenter
using AlignedAllocs

DocMeta.setdocmeta!(AlignedAllocs, :DocTestSetup, :(using AlignedAllocs); recursive=true)

makedocs(
    sitename = "AlignedAllocs.jl",
    author = "Jeffrey Sarnoff",
    modules = [AlignedAllocs],
    format = Documenter.HTML(),
    strict = true,
    pages = [
        "Home" => "index.md",
        "User Guide" => "guide.md",
        "API Reference" => "reference.md",
    ],
)

deploydocs(
    repo = "github.com/JeffreySarnoff/AlignedAllocs.jl",
    devbranch = "main",
    target = "build",
)
