using MutatingOrNot: void, similar
using Test
using Zygote: Zygote
using ForwardDiff: ForwardDiff

@inline f!(y, x) = @. y=x^2
g(x) = sum(f!(void, x))

is_similar(x::T, y::T) where T = (axes(x)==axes(y))

@testset "MutatingOrNot.jl" begin
    let (x,y) = void
        @test void[1] == void
        @test void.prop == void
        @test (x,y) == (void,void)
        u, v = randn(10), randn(10)
        @test is_similar(u, similar(u, void))
        @test similar(u, v) === v
    end
    let x = randn(10), y = similar(x)
        @test f!(y,x) == f!(void,x)
        @test (@allocated f!(y,x)) == 0
        @test Zygote.gradient(g, x)[1] ≈ 2x
        @test ForwardDiff.gradient(g, x) ≈ 2x
    end
end
