module MutatingOrNot

abstract type Void end
struct BasicVoid <: Void end

const void = BasicVoid()

Base.show(io::IO, ::Void) = print(io, "void")

Base.getproperty(::Void, ::Symbol) = void
Base.getindex(::Void, args...) = void
Base.iterate(::Void, state = nothing) = (void, nothing)

Broadcast.materialize!(::Void, bc::Broadcast.Broadcasted) = Broadcast.materialize(bc)

#========== for Julia <1.9 ==========#

using PackageExtensionCompat
function __init__()
    @require_extensions
end

end
