@testset "AlignedAllocs.jl" begin
    @test AlignedAllocs.CACHE_LINE_SIZE >= 32
    vec = memalign(Float32, 128, 64)
    zvec = memalign_clear(UInt16, 256, 64)
    @test length(vec) == 128
    @test length(zvec) == 256
    @test zvec[1] == 0
    @test UInt64(pointer(vec)) % AlignedAllocs.CACHE_LINE_SIZE == 0
    @test UInt64(pointer(zvec)) % AlignedAllocs.CACHE_LINE_SIZE == 0
end
