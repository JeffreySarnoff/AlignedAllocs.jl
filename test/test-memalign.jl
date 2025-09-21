using Test
using AlignedAllocs

const TEST_ALIGNMENT = 64

@testset "memalign returns aligned storage" begin
    vect = memalign(Float64, 32, TEST_ALIGNMENT)
    @test length(vect) == 32
    addr = UInt(pointer(vect))
    @test addr % TEST_ALIGNMENT == 0
    @test alignment(vect) >= TEST_ALIGNMENT
    vect .= 3.25
    @test all(vect .== 3.25)
end

@testset "memalign_clear zero-initializes" begin
    vect = memalign_clear(UInt16, 48, TEST_ALIGNMENT)
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
    @test_throws ArgumentError memalign(UInt64, 0, TEST_ALIGNMENT)
    @test_throws ArgumentError memalign(UInt64, -5, TEST_ALIGNMENT)
    @test_throws ArgumentError memalign(UInt64, 8, 24)
    @test_throws ArgumentError memalign(UInt64, 8, 8)
    @test_throws ArgumentError memalign(String, 4, TEST_ALIGNMENT)
    @test_throws OverflowError memalign(Float64, typemax(Int), TEST_ALIGNMENT)
end

@testset "alignment helper" begin
    base = zeros(Int, 8)
    value = alignment(base)
    @test value > 0
    @test Base.ispow2(value)
    @test UInt(pointer(base)) % value == 0
end
