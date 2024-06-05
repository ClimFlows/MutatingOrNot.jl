module MutatingOrNot

abstract type Void end
struct BasicVoid <: Void end

const void = BasicVoid()

Base.show(io::IO, ::Void) = print(io, "void")

@inline Base.getproperty(v::Void, ::Symbol) = v
@inline Base.getindex(v::Void, args...) = v
@inline Base.iterate(v::Void, state = nothing) = (v, nothing)

@inline Broadcast.materialize!(::Void, bc::Broadcast.Broadcasted) = Broadcast.materialize(bc)

# for broadcasting with ManagedLoops
Base.getindex(::Nothing, v::Void) = v

#========== for Julia <1.9 ==========#

using PackageExtensionCompat
function __init__()
    @require_extensions
end

end
