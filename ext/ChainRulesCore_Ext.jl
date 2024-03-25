module ChainRulesCore_Ext

using MutatingOrNot: Void
using ChainRulesCore: ChainRulesCore, RuleConfig, HasReverseMode, NoTangent, rrule_via_ad

function ChainRulesCore.rrule(config::RuleConfig{>:HasReverseMode}, ::typeof(Broadcast.materialize!), ::Void, bc)
    Ω, back = rrule_via_ad(config, Broadcast.materialize, bc)
    materialize!_pullback(∂Ω) = NoTangent(), back(∂Ω)...
    return Ω, materialize!_pullback
end

end
