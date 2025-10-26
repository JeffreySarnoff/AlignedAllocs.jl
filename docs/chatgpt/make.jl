# docs/make.jl
# Build with Julia 1.12+
using Pkg
# Activate a scratch environment for docs
Pkg.activate(@__DIR__)
# Ensure dependencies
Pkg.add([
    PackageSpec(name="Documenter", version="1"),
    PackageSpec(name="FixedSizeArrays"), # used in examples
])

# Load the project source files directly
push!(LOAD_PATH, joinpath(@__DIR__, "..", ".."))

using Documenter

# Bring the module into scope
# We include the source files directly to avoid needing a full package structure.
# This assumes the three files are located at project root (two levels up from docs/).
Base.include(Main, joinpath(@__DIR__, "..", "AlignedAllocs.jl"))

# The module in the provided code is named `AlignedAllocs`.
const _Mod = get(Main, :AlignedAllocs, nothing)
if _Mod === nothing
    error("Failed to load the AlignedAllocs module. Ensure AlignedAllocs.jl defines `module AlignedAllocs ... end`.")
end

DocMeta.setdocmeta!(_Mod, :DocTestSetup, :(using AlignedAllocs); recursive=true)

makedocs(
    modules=[_Mod],
    clean=true,
    doctest=true,
    format=Documenter.HTML(prettyurls=get(ENV, "CI", nothing) == "true"),
    sitename="AlignedAllocs.jl",
    authors="",
    pages=[
        "Home" => "index.md",
        "User Guide" => "user_guide.md",
        "Technical Guide" => "technical_guide.md",
        "API" => "api.md",
    ],
)

# In a real package you would also deploy with `deploydocs`.
println("Docs built. Open build/index.html to view.")
