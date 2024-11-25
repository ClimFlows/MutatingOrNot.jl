module MutatingOrNot

"""
    abstract type Void end

Instances `v` of types subtyping `Void`, especially [`void`](@ref), when passed
as an output argument, are meant to signal that this argument is not allocated,
and needs to be. The aim is to implement both mutating and non-mutating styles
in a single place, while facilitating the pre-allocation of output arguments before
calling the mutating, non-allocating variant.

To facilitate this, the following behavior is implemented whenever `v::Void`
* `(; x, y, z) = v` results in `x==v` etc.
* `x, y, z = v` results in `x==v` etc.
* `@. v = expr` returns `@. expr`

See also [`similar!`](@ref) and [`has_dryrun`](@ref).
"""
abstract type Void end

"""
    struct BasicVoid <: Void end
See [`Void`](@ref).
"""
struct BasicVoid <: Void end

"""
    abstract type DryRun<:Void end

Instances `v` of types subtyping `DryDryn`, especially [`dryrun`](@ref), when passed
as an output argument, are meant to signal that this argument needs to be allocated,
but that no actual computation should take place. See [`has_dryrun`](@ref).
"""
abstract type DryRun <: Void end

"""
    struct BasicDryRun <: DryRun end
See [`DryRun`](@ref).
"""
struct BasicDryRun <: DryRun end

"""
`void` is the only instance of the singleton type `BasicVoid <: Void`. When passed
as an output argument, it is meant to signal that this argument is not allocated,
and needs to be.
See [`Void`](@ref), [`similar!`](@ref) and [`has_dryrun`](@ref).
"""
const void = BasicVoid()

"""
`dryrun` is the only instance of the singleton type `BasicDryRun`. When passed
as an output argument, it is meant to signal that one wants to allocate
that output argument, but not to do actual work. See [`void`](@ref) and [`has_dryrun`](@ref).
"""
const dryrun = BasicDryRun()

"""
`has_dryrun(x)` returns
* `true` if `x::DryRun`,
* `any(has_dryrun, x)` if `x` is a (named) tuple,
* and false otherwise.

Use it to avoid computations when only allocations are desired. Example:

    function f!(x, y, z)
        # allocations, if needed
        a = similar!(x.a, y)
        b = similar!(x.b, z)

        # early exit, if requested
        has_dryrun(x) && return (; a, b)

        # computations
        a = @. a = y*y
        b = @. b = exp(z)
        return (; a, b)
    end

In the above example,
* the special properties of `x_::Void` (see [`Void`](@ref)) are used
* `x = f!(void, y)` is the non-mutating variant of `f!`
* `x = f!(dryrun, y)` just allocates x, without performing actual work
* `x = f!(x, y)` mutates the pre-allocated x (non-allocating)
"""
has_dryrun(x) = false
has_dryrun(::DryRun) = true
has_dryrun(x::Union{Tuple, NamedTuple}) = any(has_dryrun, x)
has_dryrun(x...) = has_dryrun(x) # multiple arguments treated as tuple

Base.show(io::IO, ::BasicVoid) = print(io, "void")
Base.show(io::IO, ::BasicDryRun) = print(io, "dryrun")

@inline Base.getproperty(v::Void, ::Symbol) = v
@inline Base.getindex(v::Void, args...) = v
@inline Base.iterate(v::Void, state = nothing) = (v, nothing)

@inline Broadcast.materialize!(::Void, bc::Broadcast.Broadcasted) = Broadcast.materialize(bc)

@inline function Broadcast.materialize!(::DryRun, bc::Broadcast.Broadcasted)
    F = Base.Broadcast.combine_eltypes(bc.f, bc.args)
    Base.Broadcast.similar(bc, F)
end

# used by ManagedLoops for broadcasting
Base.getindex(::Nothing, v::Void) = v

"""
    xx = similar!(x, y...)

Convenience function that replaces more concisely:

    if x::Void
        xx = similar(y...)
    else
        xx = x
    end

The goal is to allocate `xx` only when a pre-allocated `x` is not provided.
[`similar(y...)`](@ref) defaults to `Base.similar(y...)` and [`similar(y)`](@ref) applies recursively to tuples and named tuples.

See also [`has_dryrun`](@ref).
"""
similar!(x, y...) = x
similar!(::Void, y...) = similar(y...)

"""
    x = similar(y...)

`similar(y...)` defaults to Base.similar(y...). Furthermore the single-argument `similar(y)` applies recursively to tuples and named tuples.
Contrary to `Base.similar`, it is not possible to specify `eltype` or `dims` in this recursive variant.
"""
similar(y...) = Base.similar(y...)
similar(y::Union{Tuple, NamedTuple}) = map(similar, y)

#========== for Julia <1.9 ==========#

using PackageExtensionCompat
function __init__()
    @require_extensions
end

end
