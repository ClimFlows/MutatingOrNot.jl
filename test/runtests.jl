using MutatingOrNot: void
using Test
using Zygote: gradient

f!(y, x) = @. y=x^2
g(x) = sum(f!(void, x))

@testset "MutatingOrNot.jl" begin
    let (x,y) = void
        @test void[1] == void
        @test void.prop == void
        @test (x,y) == (void,void)
    end
    let x = randn(10), y = similar(x)
        @test f!(y,x) == f!(void,x)
        @test (@allocated f!(y,x)) == 0
        @test gradient(g, x)[1] ≈ 2x
    end
end
