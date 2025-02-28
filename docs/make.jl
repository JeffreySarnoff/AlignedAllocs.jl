using AlignedAllocs
using Documenter

DocMeta.setdocmeta!(AlignedAllocs, :DocTestSetup, :(using AlignedAllocs); recursive = true)

const page_rename = Dict("developer.md" => "Developer docs") # Without the numbers
const numbered_pages = [
    file for file in readdir(joinpath(@__DIR__, "src")) if
    file != "index.md" && splitext(file)[2] == ".md"
]

makedocs(;
    modules = [AlignedAllocs],
    authors = "Jeffrey Sarnoff <jeffrey.sarnoff@gmail.com>",
    repo = "https://github.com/JeffreySarnoff/AlignedAllocs.jl/blob/{commit}{path}#{line}",
    sitename = "AlignedAllocs.jl",
    format = Documenter.HTML(; canonical = "https://JeffreySarnoff.github.io/AlignedAllocs.jl"),
    pages = ["index.md"; numbered_pages],
)

deploydocs(; repo = "github.com/JeffreySarnoff/AlignedAllocs.jl")
