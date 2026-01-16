"""
    abstract type Void <: ArrayAllocator end

Instances of types subtyping `Void`, especially [`void`](@ref), when passed
as an output argument, are meant to signal that this argument is not allocated,
and needs to be. The aim is to implement both mutating and non-mutating styles
in a single place, while facilitating the pre-allocation of output arguments before
calling the mutating, non-allocating variant.

More specifically:

    malloc(::Void, args...) = similar(args...)
    mfree(::Void, x) = x

See [`ArrayAllocator`](@ref), [`malloc`](@ref), [`mfree`](@ref) , [`set_dryrun`](@ref) and [`has_dryrun`](@ref).
See also [`void`](@ref), [`dryrun`](@ref)
"""
abstract type Void <: ArrayAllocator end

@inline malloc(::Void, args...) = malloc_void(args...)
"""
    x = malloc_void(args...)

`malloc_void(args...)` defaults to `similar(y...)`. Furthermore the single-argument `malloc_void(y)` applies recursively to tuples and named tuples.
Contrary to `similar`, it is not possible to specify `eltype` or `dims` in this recursive variant.
"""
@inline malloc_void(y...) = similar(y...)
@inline malloc_void(y::Union{Tuple, NamedTuple}) = map(malloc_void, y)

"""
See [`void`](@ref), [`Void`](@ref).
"""
struct BasicVoid <: Void end

"""
`void` is the only instance of the singleton type `BasicVoid <: Void`. When passed
as an output argument, it is meant to signal that this argument is not allocated,
and needs to be. Moreover:

    has_dryrun(void)  == false
    set_dryrun(void) == dryrun

See [`Void`](@ref), [`DryRun`](@ref).
"""
const void = BasicVoid()

Base.show(io::IO, ::BasicVoid) = print(io, "void")

@inline set_dryrun(::BasicVoid) = dryrun

# FIXME: this must be generalized for ArrayAllocator
@inline Broadcast.materialize!(::Void, bc::Broadcast.Broadcasted) = Broadcast.materialize(bc)

# used by ManagedLoops for broadcasting
Base.getindex(::Nothing, v::Void) = v
