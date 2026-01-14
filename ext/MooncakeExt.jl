module MooncakeExt

using Mooncake: Mooncake, @zero_adjoint, @is_primitive, primal, DefaultCtx, CoDual, NoTangent, NoFData, NoRData
using MutatingOrNot.Allocators: malloc, mfree, SmartAllocator, debug

@zero_adjoint DefaultCtx Tuple{typeof(mfree), Any}
@zero_adjoint DefaultCtx Tuple{typeof(mfree), Any, Any}

Mooncake.tangent_type(::Type{SmartAllocator}) = NoTangent

@is_primitive DefaultCtx Tuple{typeof(malloc), SmartAllocator, Array}
Mooncake.rrule!!(::CoDual{typeof(malloc)}, cosmart, cox) = malloc_rrule!!(cosmart, cox)

function malloc_rrule!!(cosmart::CoDual{SmartAllocator, NoFData}, cox::CoDual)
    smart, x = primal(cosmart), primal(cox)
    debug && debug_store(:malloc_rrule!!, store)
    y, ∂y = malloc(smart, x), malloc(smart, x)
    debug && debug_store(:malloc_rrule!!, store)
    
    function malloc_pb(::NoRData)
        mfree(smart, ∂y)
        return NoRData(), NoRData(), NoRData() # rdata for (malloc, smart, x)
    end

    fill!(∂y, zero(eltype(x)))
    return CoDual(y, ∂y), malloc_pb
end

end
