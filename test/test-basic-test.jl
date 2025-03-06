@testset "AlignedAllocs.jl" begin
    vec = memalign(Float32, 128, 64)
    zvec = memalign_clear(UInt16, 256, 64)
    @test length(vec) == 128
    @test length(zvec) == 256
    @test zvec[1] == 0
    @test UInt64(pointer(vec)) % 64 == 0
    @test UInt64(pointer(zvec)) % 64 == 0
end
