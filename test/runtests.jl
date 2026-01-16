import Zygote, ForwardDiff, Mooncake, DifferentiationInterface as DI
using Base: summarysize
using Test

using MutatingOrNot

@assert !isnothing(Base.get_extension(MutatingOrNot, :MooncakeExt))

@inline f!(y, x) = @. y=x^2
g(x) = sum(f!(void, x))

is_similar(x::T, y::T) where T = (axes(x)==axes(y))

@info "show" void dryrun

@testset "MutatingOrNot" begin
    let (x,y) = void
        @test void[1] == void
        @test void.prop == void
        @test (x,y) == (void,void)
        u, v = randn(10), randn(10)
        @test is_similar(u, malloc(void, u))
        @test malloc(v, u) === v
        @test set_dryrun(void) === dryrun
        @test set_dryrun(dryrun) === dryrun
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

#=================== Allocators ===============#

const smart = SmartAllocator()

prepare(x, tmp) = DI.prepare_gradient(loss, DI.AutoMooncake(), x, DI.Constant(tmp))
grad(x, tmp) = DI.gradient(loss, DI.AutoMooncake(), x, DI.Constant(tmp))
prepgrad!(x, ∂x, prep, tmp) = DI.gradient!(loss, ∂x, prep, DI.AutoMooncake(), x, DI.Constant(tmp))

prepare(x) = DI.prepare_gradient(loss, DI.AutoMooncake(), x)
grad(x) = DI.gradient(loss, DI.AutoMooncake(), x)
prepgrad!(x, ∂x, prep) = DI.gradient!(loss, ∂x, prep, DI.AutoMooncake(), x)

loss(x) = loss(x, smart)

function loss(x, tmp)
    y = malloc(tmp, x) # zero ∂y (fwd) or free ∂y (bwd)
    for i in eachindex(x,y)
        y[i] = x[i]^2         # ∂x += 2x ∂y
    end
    v = sum(y)         # ∂y += ∂v
    mfree(tmp, y)
    return v/2          # ∂v = 1/2
end

@testset "Allocators" begin
    x = randn(100_000)

    smart_dryrun = set_dryrun(smart)
    @test has_dryrun(smart_dryrun)
    @test set_dryrun(smart_dryrun) === smart_dryrun

    let prep=prepare(x, void)
        ∂x = similar(x);
        prepgrad!(x, ∂x, prep, void)
        @test ∂x ≈ x
        @info "" summarysize(void) summarysize(prep)
        @showtime prepgrad!(x, ∂x, prep, void)
    end

    let prep = prepare(x, smart)
        ∂x = similar(x);
        prepgrad!(x, ∂x, prep, smart)
        @test ∂x ≈ x
        @info "" summarysize(smart) summarysize(prep)
        @showtime prepgrad!(x, ∂x, prep, smart)
    end

    let prep = prepare(x)
        ∂x = similar(x);
        prepgrad!(x, ∂x, prep)
        @test ∂x ≈ x
        @info "" summarysize(smart) summarysize(prep)
        @showtime prepgrad!(x, ∂x, prep)
    end
end
