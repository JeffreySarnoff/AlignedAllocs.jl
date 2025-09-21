using Documenter, AlignedAllocs

makedocs(
    modules = [AlignedAllocs],
    authors = "Jeffrey Sarnoff",
    repo = "https://github.com/JeffreySarnoff/AlignedAllocs.jl/blob/{commit}{path}#{line}",
    sitename = "AlignedAllocs.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://jeffreysarnoff.github.io/AlignedAllocs.jl",
        repolink = "https://github.com/JeffreySarnoff/AlignedAllocs.jl",
        edit_link = "main",
        assets = String[],
        sidebar_sitename = false,
    ),
    pages = [
        "Home" => "index.md",
        "User Guide" => "guide.md",
        "API Reference" => "reference.md",
    ],
    checkdocs = :none,
    linkcheck = true,
)

deploydocs(;
    repo = "github.com/JeffreySarnoff/AlignedAllocs.jl.git",
    target = "build",
    devbranch = "main",
    push_preview = true,
)
