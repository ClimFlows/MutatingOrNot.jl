module MutatingOrNot

export malloc, mfree, has_dryrun, set_dryrun, void, dryrun, SmartAllocator

"""
Parent type for array allocators. Array allocators can be passed as output arguments 
instead of preallocated arrays needed for intermediate computations. For instance:

    function myfun1(tmp::Union{AbstractArray, ArrayAllocator}, input)
        x = malloc(tmp, ...) # allocate temporary array y, as with `similar(...)`
        ...
        ret = ...            # do some computation that needs `x` as scratch space
        return ret, x
    end

    alloc = ... # create allocator
    ret0, x = myfun1(alloc, input0) # allocates
    ret1, _ = myfun1(x, input1)     # `x` is an array => should not allocate

The point of `x` being returned is to use it in subsequent calls 
and (potentially) avoid new allocations. A slightly different pattern is:

    function myfun1(tmp::Union{AbstractArray, ArrayAllocator}, input)
        x = malloc(tmp, ...) # allocate temporary array y, as with `similar(...)`
        ...
        ret = ...            # do some computation that needs `x` as scratch space
        x = mfree(tmp, x)    # `free` array x, in a sense depending on tmp
        return ret, x
    end

    alloc = ... # create allocator
    ret0, tmp = myfun1(alloc, input0) # allocates
    ret1, _ = myfun1(tmp, input1)     # `tmp` may be an array or an array allocator

The precise behavior of `mfree` depends on the concrete type of `tmp`.
`mfree(tmp, x)` may return the array `x` or `tmp` itself.
Allocators are allowed to reuse memory passed to `mfree` for subsequent calls to `malloc`. 
Therefore an array must not be read/written after being passed to `mfree`.

Beyond arrays, nested (named) tuples arrays are supported. For this, the following behavior 
is implemented whenever `v::ArrayAllocator`

    (; x, y, z) = tmp    # results in `x==tmp` etc.
    x, y, z = tmp        # results in `x==tmp` etc.
    @. tmp = expr        # returns `@. expr`

This enables the following, more advanced pattern:

    function example(tmp::Union{AbstractArray, ArrayAllocator}, input)
        ret1, x = myfun1(tmp.x, input)  # uses `mfree`
        ret2, y = myfun1(tmp.y, input)  # uses `mfree`
        # we are not allowed to read/write `x` or `y` here since they have been freed
        # for instance `tmp` may have reused the memory allocated for `x`
        # when allocating `y`, so that `x` and `y` refer to the same memory !
        ret = ...            # do some computation with ret1 and ret2
        return ret, mfree(tmp, (; x,y))
    end

    alloc = ... # create allocator
    ret0, tmp = myfun1(alloc, input0)  # allocates
    ret1, _  = myfun1(tmp, input1)     # `tmp` may be a named tuple of arrays, or an array allocator

See [`malloc`](@ref), [`mfree`](@ref) , [`set_dryrun`](@ref) and [`has_dryrun`](@ref).
"""
abstract type ArrayAllocator end

@inline Base.getproperty(v::ArrayAllocator, ::Symbol) = v
@inline Base.getindex(v::ArrayAllocator, args...) = v
@inline Base.iterate(v::ArrayAllocator, state = nothing) = (v, nothing)

"""
When `tmp::ArrayAllocator`, `has_dryrun(tmp)==true` signals that only allocations should
take place, but not actual work (computations). Furthermore:

    has_dryrun(x) == any(has_dryrun, x) # if `x` is a (named) tuple
    has_dryrun(x) == false              # if `x` is an array

Use it to avoid computations when only allocations are desired. Example:

    function f!(tmp, x, y)
        # allocations, if needed
        a = malloc(tmp.a, x)   # same type and shape as `x`
        b = malloc(tmp.b, y)   # same type and shape as `y`

        # early exit, if requested
        has_dryrun(x) && return (; a, b)

        # computations
        a = @. a = y*y
        b = @. b = exp(z)
        return (; a, b)
    end

In the above example,
* the special properties of `x_::Void` (see [`Void`](@ref)) are used
* `x = f!(void, y)` is the non-mutating variant of `f!`
* `x = f!(dryrun, y)` just allocates x, without performing actual work
* `x = f!(x, y)` mutates the pre-allocated x (non-allocating)
"""
has_dryrun(x) = false
has_dryrun(x::Union{Tuple, NamedTuple}) = any(has_dryrun, x)
# has_dryrun(x...) = has_dryrun(x) # multiple arguments treated as tuple

"""
    x = malloc(tmp, args...)

When `tmp::ArrayAllocator`, return array `x`, similarly to `similar(args...)`. The allocator `tmp` may
provide more or less sophisticated allocation strategies.

Otherwise, especially when `tmp` is an array or a (nested) (named) tuple thereof, return `tmp` itself.
The goal is to allocate `x` only when a pre-allocated `tmp` is not provided.

See [`void`](@ref) and [`SmartAllocator`](@ref).
"""
@inline malloc(x, args...) = x

"""
    mfree(tmp, x)

Free array `x`, which was previously allocated by `malloc(tmp, ...)`. Whether anything is actually done depends
on the allocator `tmp`. 
See [`void`](@ref) and [`SmartAllocator`](@ref).
"""
mfree(_, x) = x

"""
    mfree(tmp)

Free allocator `tmp`. Whether anything is actually done depends
on the allocator `tmp`. See `void` and `SmartAllocator`.
"""
mfree(_) = nothing

include("julia/void.jl")
include("julia/dryrun.jl")
include("julia/smart.jl")

#========== for Julia <1.9 ==========#

using PackageExtensionCompat
function __init__()
    @require_extensions
end

end
