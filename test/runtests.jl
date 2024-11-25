using MutatingOrNot: void, dryrun, has_dryrun, similar!
using Test
using Zygote: Zygote
using ForwardDiff: ForwardDiff

@inline f!(y, x) = @. y=x^2
g(x) = sum(f!(void, x))

is_similar(x::T, y::T) where T = (axes(x)==axes(y))

@info "show" void dryrun

@testset "MutatingOrNot.jl" begin
    let (x,y) = void
        @test void[1] == void
        @test void.prop == void
        @test (x,y) == (void,void)
        u, v = randn(10), randn(10)
        @test is_similar(u, similar!(void, u))
        @test similar!(v, u) === v
    end
    let x = randn(10), y = similar(x)
        @test f!(y,x) == f!(void,x)
        @test is_similar(f!(void,x), f!(dryrun,x))
        @test (@allocated f!(y,x)) == 0
        @test Zygote.gradient(g, x)[1] ≈ 2x
        @test ForwardDiff.gradient(g, x) ≈ 2x
        @test has_dryrun(dryrun)
    end
end
