module Allocators

using ..MutatingOrNot: Void, BasicVoid
import ..MutatingOrNot: similar!

const debug = false

export malloc, mfree, SmartAllocator

"""
Parent type for array allocators. An instance `tmp::ArrayAllocator` is to be
used along the following pattern:

    y = malloc(tmp, args...) # allocate temporary array y
    ... # do some computation with y
    mfree(tmp, y) # `free` array y, in a sense depending on tmp
"""
abstract type ArrayAllocator <: Void end
similar!(tmp::ArrayAllocator, args...) = malloc(tmp, args...)

"""
    y = malloc(tmp, args...)

Return array `y`, similarly to `similar(args...)`. The allocator `tmp` may
provide more or less sophisticated allocation strategies. See `dumb` and `SmartAllocator`.
"""
function malloc end

"""
    mfree(tmp, y)

Free array `y`, which was previously allocated by `malloc`. Whether anything is actually done depends
on the allocator `tmp`. See `dumb` and `SmartAllocator`.
"""
mfree(::Void, _) = nothing
mfree(::A, ::A) where { A<:AbstractArray } = nothing

"""
    mfree(tmp)

Free allocator `tmp`. Whether anything is actually done depends
on the allocator `tmp`. See `dumb` and `SmartAllocator`.
"""
mfree(_) = nothing

#======================  dumb allocator ===================#

struct Dumb <: ArrayAllocator end
"""
The singleton `dumb` describes the simplest possible allocation strategy:

    malloc(dumb, args...) == similar(args...)
    mfree(dumb) = nothing

Especially, freeing memory is actually left to Julia's garbage collector.
"""
const dumb = Dumb()
Base.show(io::IO, ::Dumb) = print(io, :dumb)

@inline malloc(::Dumb, args...) = similar(args...)

#====================== smart allocator ===================#

struct ArrayStore{T,N,A<:AbstractArray{T,N}}
    arrays::Vector{A}
    tags::Vector{Tuple{Bool, NTuple{N, Int}}} # for each array: (free/busy, size)
end

struct SmartAllocator <: ArrayAllocator
    stores::Dict{UInt64, ArrayStore}
end
"""
    smart = SmartAllocator()
Return a smart allocator `smart`, with the following behavior:
- internally, `smart` maintains a store tracking previously allocated arrays, 
  marked as either `busy` or `free`.
- `y = malloc(smart, args...)` searches that store for an array 
  with the appropriate eltype and shape. If this fails, 
  it allocates one with `similar(args...)`. Either way, `y` is marked as `busy` in the store.
- `mfree(smart, y)` keeps `y` in the store and marks it as free, so that a later call to `malloc` can reuse it
- any `mfree` must have a corresponding `malloc`
- `mfree(smart)` marks all arrays in the store as `free` but does not actually free anything.
- only `empty!(smart)` actually empties the store, allowing Julia's garbage collector to act. 

Note of caution:
- arrays from the store are reused only if they have the exact same eltype and shape as requested by `malloc`.
- to avoid runaway memory usage, any `malloc` must have a corresponding `mfree`
- this allocator is smart only if the eltype and shape requested via `malloc` belong to a small set of possibilities.
"""
SmartAllocator() = SmartAllocator(Dict{UInt64, ArrayStore}())
Base.empty!(smart::SmartAllocator) = empty!(smart.stores)

# malloc

malloc(smart::SmartAllocator, x::AbstractArray) = malloc_smart(smart, x, eltype(x), size(x))
malloc(smart::SmartAllocator, x::AbstractArray, ::Type{T}) where T = malloc_smart(smart, x, eltype(x), size(x))

function malloc_smart(smart::SmartAllocator, x, ::Type{T}, sz::NTuple{N,Int}) where {T,N}
    (; arrays, tags) = store = get_store(smart, x, T, sz)
    debug && debug_store(malloc, store)
    i = findfirst(tag->(tag[1] && tag[2]==sz), tags)
    if isnothing(i)
        y = similar(x, T, sz)
        push!(arrays, y)
        push!(tags, (false, sz))
    else
        y = store.arrays[i]
        tags[i]  =(false, sz) # mark array as busy
        debug && @info "reusing array" i pointer(y) map(pointer, store.arrays)
    end
    debug && debug_store(malloc, store)
    return y
end

# mfree

mfree(smart::SmartAllocator) = foreach(mfree, values(stores(smart)))

function mfree(store::ArrayStore)
    empty!(store.arrays)
    empty!(store.tags)
end

function mfree(smart::SmartAllocator, x::AbstractArray)
    (; arrays, tags) = store = get_store(smart, x)
    debug && debug_store(mfree, store)

    i = findfirst(y->pointer(y)==pointer(x), arrays)
    @assert !isnothing(i) "Array to be freed not tracked"
    @assert !tags[i][1] "Array to be freed is already free"
    tags[i] = (true, size(x))

    debug && debug_store(mfree, store)
    return nothing
end

# helpers

function debug_store(fun, store)
    @info string(fun) store.tags map(pointer, store.arrays)
end

@inline get_store(smart, x) = get_store(smart, x, eltype(x), size(x))
@inline function get_store(smart, x, ::Type{T}, sz::NTuple{N,Int}) where {T,N}
    A = similar_type(x, T, sz)
    get!(stores(smart), hash(A)) do 
        ArrayStore{T,N,A}(A[], Tuple{Bool, NTuple{N, Int}}[])
    end :: ArrayStore{T,N,A} # for type stability
end

@generated function similar_type(::A, ::Type{T}, ::NTuple{N, Int}) where {T, N, A<:AbstractArray}
    B = similar(A, ntuple(i->0, Val(N)))
    return typeof(similar(B, T))
end

@inline stores(smart) = getfield(smart, :stores)

end # module