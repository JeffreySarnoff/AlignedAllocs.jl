
# test/runtests.jl
# Pkg.test()-style wrapper for AlignedAllocs tests (Julia 1.12+).
#
# Usage:
#   1) Put your sources (AlignedAllocs.jl, FixedAlignedAllocs.jl, precompilation.jl)
#      in some folder, e.g. /path/to/srcdir
#   2) Option A (recommended): set environment variable and run tests:
#        $ set ALIGNED_ALLOCS_SRC=/path/to/srcdir
#        $ julia --project=. -e 'using Pkg; Pkg.test()'
#      Option B: copy the three source files to this project root directory,
#      right next to Project.toml; the test will auto-detect them.
#
# Notes:
#   - Per your request, any internal reference to "memalign_clear_fixed" is assumed
#     to be replaced by "memalign_clear_fix" in your sources.
#   - This test suite exercises alignment guarantees, zero-initialization,
#     argument validation, overflow checks, and stress scenarios.

using Test
using Random

# -------------------- Locate sources --------------------

const ROOT = abspath(joinpath(@__DIR__, ".."))
const SRC_ENV = get(ENV, "ALIGNED_ALLOCS_SRC", nothing)

function _candidate_paths()
    paths = String[]
    if SRC_ENV !== nothing
        push!(paths, SRC_ENV)
    end
    # Also try the project root if files are placed next to Project.toml
    push!(paths, ROOT)
    return unique(paths)
end

function _find_sources()
    for dir in _candidate_paths()
        a = joinpath(dir, "AlignedAllocs.jl")
        b = joinpath(dir, "FixedAlignedAllocs.jl")
        c = joinpath(dir, "precompilation.jl")
        if isfile(a) && isfile(b) && isfile(c)
            return (a,b,c)
        end
    end
    error("Could not find required sources. Set ALIGNED_ALLOCS_SRC or place files at project root.")
end

let (A,B,C) = _find_sources()
    include(A)
    include(B)
    include(C)
end

const AA = AlignedAllocs

# -------------------- Helpers --------------------

# Check "power-of-two and ≥ 16" alignment rule
is_valid_alignment(a::Integer) = a ≥ 16 && (a & (a - 1)) == 0

# Return the integer alignment (power-of-two divisor of pointer address)
ptr_alignment(xs) = AA.alignment(xs)

const SmallTypes = (UInt8, Int8, UInt16, Int16, UInt32, Int32, UInt64, Int64, Float32, Float64)

# -------------------- Tests --------------------

@testset "Module setup & cache line size" begin
    @test isdefined(AA, :CACHE_LINE_SIZE)
    @test AA.CACHE_LINE_SIZE isa Integer
    @test AA.CACHE_LINE_SIZE > 0
    @test is_valid_alignment(AA.CACHE_LINE_SIZE)
    @test 16 ≤ AA.CACHE_LINE_SIZE ≤ 1024
end

@testset "alignment(::AbstractArray) basics" begin
    @test AA.alignment(Int[]) == 0  # empty arrays report 0
    xs = [1,2,3]
    a = AA.alignment(xs)
    @test a == 0 || ((a & (a - 1)) == 0)
end

@testset "memalign_vec: success paths & invariants" begin
    for T in SmallTypes, nitems in (1, 17, 128, 1024), align in (AA.CACHE_LINE_SIZE, 16, 32, 64, 128)
        @testset "T=$(T), n=$nitems, align=$align" begin
            v = AA.memalign_vec(T, nitems; align=align)
            @test eltype(v) === T
            @test length(v) == nitems
            got = ptr_alignment(v)
            @test got ≥ align
            @test got % align == 0
            if nitems ≥ 3
                v[1] = zero(T)
                v[2] = one(T)
                v[end] = convert(T, 42)
                @test v[1] == zero(T)
                @test v[2] == one(T)
                @test v[end] == convert(T, 42)
            end
        end
    end
end

@testset "memalign_clear_vec: zero-initialization" begin
    for T in (UInt8, UInt16, UInt32, UInt64, Int32, Float64), nitems in (1, 33, 257), align in (16, 64, AA.CACHE_LINE_SIZE)
        @testset "T=$(T), n=$nitems, align=$align" begin
            v = AA.memalign_clear_vec(T, nitems; align=align)
            @test eltype(v) === T
            @test length(v) == nitems
            got = ptr_alignment(v)
            @test got ≥ align
            @test got % align == 0
            # Verify all bytes are zero
            unsafe_bytes = unsafe_wrap(Vector{UInt8}, Base.unsafe_convert(Ptr{UInt8}, pointer(v)), sizeof(T)*nitems; own=false)
            @test all(==(0x00), unsafe_bytes)
        end
    end
end

@testset "Argument validation & error paths" begin
    struct NotBits
        s::String
    end
    @test_throws ArgumentError AA.memalign_vec(NotBits, 8)
    @test_throws ArgumentError AA.memalign_clear_vec(NotBits, 8)

    @test_throws ArgumentError AA.memalign_vec(Int, 0)
    @test_throws ArgumentError AA.memalign_clear_vec(Int, 0)
    @test_throws ArgumentError AA.memalign_vec(Int, -5)
    @test_throws ArgumentError AA.memalign_clear_vec(Int, -5)

    @test_throws ArgumentError AA.memalign_vec(Int, 8; align=12)
    @test_throws ArgumentError AA.memalign_clear_vec(Int, 8; align=1)
end

@testset "_nbytes overflow behavior" begin
    @test_throws OverflowError AA._nbytes(UInt64, typemax(Int))
end

@testset "Windows vs POSIX pathways - smoke checks" begin
    v = AA.memalign_vec(Float64, 4; align=AA.CACHE_LINE_SIZE)
    @test length(v) == 4
    @test eltype(v) === Float64
end

@testset "alignment(::NTuple) returns min alignment" begin
    a = AA.memalign_vec(UInt8, 64; align=64)
    b = AA.memalign_vec(UInt8, 64; align=16)
    tup_align = AA.alignment((a, b))
    @test tup_align == min(ptr_alignment(a), ptr_alignment(b))
end

@testset "Fixed-size helpers: memalign_fix / memalign_clear_fix / memalign_seq" begin
    if isdefined(AA, :memalign_fix) && isdefined(AA, :memalign_clear_fix)
        F = AA.memalign_fix(Float32, 16; align=AA.CACHE_LINE_SIZE)
        @test size(F) == (16,)
        @test eltype(F) === Float32
        F[1] = 1f0; F[end] = 2f0
        @test F[1] == 1f0 && F[end] == 2f0

        Z = AA.memalign_clear_fix(Int32, 8; align=64)
        @test all(==(0), Z)

        # memalign_seq is expected to be implemented in terms of memalign_clear_fix
        S = AA.memalign_seq(Float64, 3, 5; align=64)
        @test length(S) == 3
        @test all(size(x) == (5,) for x in S)
        @test all(eltype(x) === Float64 for x in S)
    else
        @info "FixedSizeArrays-dependent APIs not available; skipping."
        @test true
    end
end

@testset "Stress: random sizes and alignments" begin
    rng = MersenneTwister(0x533a7f1)
    for trial in 1:50
        T = rand(rng, SmallTypes)
        n = rand(rng, 1:1024)
        align = (1 << rand(rng, 4:10))  # 16 .. 1024
        v = AA.memalign_vec(T, n; align=align)
        @test eltype(v) === T
        @test length(v) == n
        got = ptr_alignment(v)
        @test got ≥ align && got % align == 0
        v[1] = zero(T)
        v[end] = convert(T, 7)
        @test v[1] == zero(T)
        @test v[end] == convert(T, 7)
    end
end

println("\n✓ All tests completed.")
