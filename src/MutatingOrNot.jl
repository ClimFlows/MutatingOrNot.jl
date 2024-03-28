module MutatingOrNot

abstract type Void end
struct BasicVoid <: Void end

const void = BasicVoid()

Base.show(io::IO, ::Void) = print(io, "void")

@inline Base.getproperty(::Void, ::Symbol) = void
@inline Base.getindex(::Void, args...) = void
@inline Base.iterate(::Void, state = nothing) = (void, nothing)

@inline Broadcast.materialize!(::Void, bc::Broadcast.Broadcasted) = Broadcast.materialize(bc)

#========== for Julia <1.9 ==========#

using PackageExtensionCompat
function __init__()
    @require_extensions
end

end
