module MooncakeExt

using Mooncake: Mooncake, @zero_adjoint, @is_primitive, primal, DefaultCtx, CoDual, NoTangent, NoFData, NoRData
using MutatingOrNot: SmartAllocator, debug, malloc_smart, mfree  

@zero_adjoint DefaultCtx Tuple{typeof(mfree), Any}
@zero_adjoint DefaultCtx Tuple{typeof(mfree), Any, Any}

Mooncake.tangent_type(::Type{<:SmartAllocator}) = NoTangent

@is_primitive DefaultCtx Tuple{typeof(malloc_smart), Any, Any, Any, Any}
Mooncake.rrule!!(::CoDual{typeof(malloc_smart)}, cosmart, cox, coT, cosize) = malloc_rrule!!(cosmart, cox, coT, cosize)

function malloc_rrule!!(cosmart::CoDual{<:SmartAllocator, NoFData}, cox::CoDual, ::CoDual{Type{T}}, cosize) where T
    smart, x, sz = primal(cosmart), primal(cox), primal(cosize)
    debug && debug_store(:malloc_rrule!!, store)
    y, ∂y = malloc_smart(smart, x, T, sz), malloc_smart(smart, x, T, sz)
    debug && debug_store(:malloc_rrule!!, store)
    
    function malloc_pb(::NoRData)
        mfree(smart, ∂y)
        return NoRData(), NoRData(), NoRData(), NoRData(), NoRData() # rdata for (malloc_smart, smart, x, T, sz)
    end

    fill!(∂y, zero(eltype(x)))
    return CoDual(y, ∂y), malloc_pb
end

end
