module Zygote_Ext

using MutatingOrNot: Void
using Zygote: @adjoint, pullback

@adjoint function Broadcast.materialize!(::Void, bc)
    Ω, back = pullback(Broadcast.materialize, bc)
    materialize!_pullback(∂Ω) = nothing, back(∂Ω)...
    return Ω, materialize!_pullback
end

end
