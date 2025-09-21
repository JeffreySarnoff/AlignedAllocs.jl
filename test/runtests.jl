using Test
using AlignedAllocs

const TEST_ALIGNMENT = 64

@testset "memalign returns aligned storage" begin
    vect = memalign(Float64, 32; align =TEST_ALIGNMENT)
    @test length(vect) == 32
    addr = UInt(pointer(vect))
    @test addr % TEST_ALIGNMENT == 0
    @test alignment(vect) >= TEST_ALIGNMENT
    vect .= 3.25
    @test all(vect .== 3.25)
end

@testset "memalign_clear zero-initializes" begin
    vect = memalign_clear(UInt16, 48; align = TEST_ALIGNMENT)
    @test length(vect) == 48
    @test all(iszero, vect)
    addr = UInt(pointer(vect))
    @test addr % TEST_ALIGNMENT == 0
end

@testset "Default alignment uses cache line" begin
    vect = memalign(UInt8, 128)
    expected = max(AlignedAllocs.CACHE_LINE_SIZE, 16)
    addr = UInt(pointer(vect))
    @test addr % expected == 0
    @test alignment(vect) >= expected
end

@testset "Argument validation" begin
    @test_throws ArgumentError memalign(UInt64, 0; align = TEST_ALIGNMENT)
    @test_throws ArgumentError memalign(UInt64, -5; align = TEST_ALIGNMENT)
    @test_throws ArgumentError memalign(UInt64, 8; align = 24)
    @test_throws ArgumentError memalign(UInt64, 8; align = 8)
    @test_throws ArgumentError memalign(String, 4; align = TEST_ALIGNMENT)
    @test_throws OverflowError memalign(Float64, typemax(Int); align = TEST_ALIGNMENT)
end

@testset "alignment helper" begin
    base = zeros(Int, 8)
    value = alignment(base)
    @test value > 0
    @test Base.ispow2(value)
    @test UInt(pointer(base)) % value == 0
end


@testset "Helper predicates" begin
    @test AlignedAllocs.is_alignment_valid(16)
    @test AlignedAllocs.is_alignment_valid(256)
    @test !AlignedAllocs.is_alignment_valid(0)
    @test !AlignedAllocs.is_alignment_valid(18)
    @test !AlignedAllocs.is_alignment_valid(-32)
end

@testset "check_args validation" begin
    @test isnothing(AlignedAllocs.check_args(UInt8, 1, 64))
    @test_throws ArgumentError AlignedAllocs.check_args(UInt8, 0, 64)
    @test_throws ArgumentError AlignedAllocs.check_args(UInt8, 4, 12)
    @test_throws ArgumentError AlignedAllocs.check_args(String, 2, 64)
end

@testset "alloc_error translations" begin
    @test isnothing(AlignedAllocs.alloc_error(Cint(0)))
    @test_throws ArgumentError AlignedAllocs.alloc_error(AlignedAllocs.EINVAL)
    @test_throws OutOfMemoryError AlignedAllocs.alloc_error(AlignedAllocs.ENOMEM)
    err = @test_throws ErrorException AlignedAllocs.alloc_error(Cint(99))
    @test occursin("99", err.value.msg)
end

@testset "zeromem zeroes buffers" begin
    buffer = fill(UInt8(0xff), 32)
    GC.@preserve buffer begin
        ptr = Base.unsafe_convert(Ptr{UInt8}, Base.pointer(buffer))
        AlignedAllocs.zeromem(ptr, length(buffer))
    end
    @test all(iszero, buffer)
end

@testset "Large alignments" begin
    align = 512
    vect = memalign(UInt64, 4, align)
    @test length(vect) == 4
    addr = UInt(pointer(vect))
    @test addr % align == 0
    @test alignment(vect) >= align
end

@testset "Alignment on empty arrays" begin
    empty_vec = Vector{Float64}(undef, 0)
    value = alignment(empty_vec)
    @test value >= 0
    @test Base.ispow2(value) || value == 0
end
