module MutatingOrNot

abstract type Void end
struct BasicVoid <: Void end

const void = BasicVoid()

Base.show(io::IO, ::Void) = print(io, "void")

@inline Base.getproperty(v::Void, ::Symbol) = v
@inline Base.getindex(v::Void, args...) = v
@inline Base.iterate(v::Void, state = nothing) = (v, nothing)

@inline Broadcast.materialize!(::Void, bc::Broadcast.Broadcasted) = Broadcast.materialize(bc)

# used by ManagedLoops for broadcasting
Base.getindex(::Nothing, v::Void) = v

"""
    xx = similar(y, x)

Convenience function that replaces more concisely:
    
    if x::Void
        xx = similar(y)
    else
        xx = x
    end

The goal is to allocate `xx` only when a pre-allocated `x` is not provided. Furthermore `similar(y)` applies recursively to tuples and named tuples.
Contrary to `Base.similar`, it is not possible to specify `eltype` or `dims`.
"""
similar(_,y) = y
similar(x,::Void) = similar(x)
similar(x::Union{Tuple, NamedTuple}) = map(similar, x)
similar(x) = Base.similar(x)
    
#========== for Julia <1.9 ==========#

using PackageExtensionCompat
function __init__()
    @require_extensions
end

end
