"""
    abstract type DryRun<:Void end

Instances `v` of types subtyping `DryDryn`, especially [`dryrun`](@ref), when passed
as an output argument, are meant to signal that this argument needs to be allocated,
but that no actual computation should take place. Especially:

    has_dryrun(::DryRun) = true

See [`has_dryrun`](@ref).
"""
abstract type DryRun <: Void end

"""
    struct BasicDryRun <: DryRun end
See [`DryRun`](@ref).
"""
struct BasicDryRun <: DryRun end

"""
`dryrun` is the only instance of the singleton type `BasicDryRun`. When passed
as an output argument, it is meant to signal that one wants to allocate
that output argument, but not to do actual work. Indeed:

    has_dryrun(dryrun) == true

See [`void`](@ref) and [`has_dryrun`](@ref).
"""
const dryrun = BasicDryRun()

Base.show(io::IO, ::BasicDryRun) = print(io, "dryrun")

has_dryrun(::DryRun) = true

# FIXME: this must be generalized for ArrayAllocator
@inline function Broadcast.materialize!(::DryRun, bc::Broadcast.Broadcasted)
    F = Base.Broadcast.combine_eltypes(bc.f, bc.args)
    Base.Broadcast.similar(bc, F)
end
