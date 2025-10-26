using Documenter
using AlignedAllocs

# Set up DocMeta for @docs blocks
DocMeta.setdocmeta!(AlignedAllocs, :DocTestSetup, :(using AlignedAllocs); recursive=true)

makedocs(;
    modules=[AlignedAllocs],
    authors="Contributors",
    repo="https://github.com/YourUsername/AlignedAllocs.jl/blob/{commit}{path}#{line}",
    sitename="AlignedAllocs.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://YourUsername.github.io/AlignedAllocs.jl",
        edit_link="main",
        assets=String[],
        sidebar_sitename=true,
    ),
    pages=[
        "Home" => "index.md",
        "User Guide" => "guide.md",
        "Technical Guide" => "technical.md",
        "API Reference" => "api.md",
    ],
    warnonly = [:missing_docs, :cross_references],
    checkdocs=:none,
)

deploydocs(;
    repo="github.com/YourUsername/AlignedAllocs.jl",
    devbranch="main",
    push_preview=true,
)
