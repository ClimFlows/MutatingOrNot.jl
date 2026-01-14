module Allocators

const debug = false

export malloc, mfree, SmartAllocator

"""
Parent type for array allocators. An instance `tmp::ArrayAllocator` is to be
used along the following pattern:

    y = malloc(tmp, args...) # allocate temporary array y
    ... # do some computation with y
    mfree(tmp, y) # `free` array y, in a sense depending on tmp
"""
abstract type ArrayAllocator end

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

"""
    y = malloc(tmp, args...)

Return array `y`, similarly to `similar(args...)`. The allocator `tmp` may
provide more or less sophisticated allocation strategies. See `dumb` and `SmartAllocator`.
"""
malloc(::Dumb, x) = similar(x)


"""
    mfree(tmp, y)

Free array `y`, which was previously allocated by `malloc`. Whether anything is actually done depends
on the allocator `tmp`. See `dumb` and `SmartAllocator`.
"""
mfree(::Dumb, _) = nothing


"""
    mfree(tmp)

Free allocator `tmp`. Whether anything is actually done depends
on the allocator `tmp`. See `dumb` and `SmartAllocator`.
"""
mfree(::Dumb) = nothing

#====================== smart allocator ===================#

struct ArrayStore{A<:AbstractArray}
    busy::Vector{A}
    free::Vector{A}
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

function malloc(smart::SmartAllocator, x::AbstractArray{T,N}) where {T,N}
    store = get_store(smart, x)
    debug && debug_store(malloc, store)
    i = findfirst(y->size(y)==size(x), store.free)
    y = if isnothing(i)
        similar(x)
    else
        popat!(store.free, i)
    end
    push!(store.busy, y)
    debug && debug_store(malloc, store)
    return y
end

# mfree

mfree(smart::SmartAllocator) = foreach(mfree, values(smart.stores))

function mfree(store::ArrayStore)
    empty!(store.free)
    empty!(store.busy)
end

function mfree(smart::SmartAllocator, x::AbstractArray)
    store = get_store(smart, x)
    debug && debug_store(mfree, store)

    @assert !any(y->y===x, store.free)
    push!(store.free, x)

    i = findfirst(y->y===x, store.busy)
    @assert !isnothing(i) 
    popat!(store.busy, i)
    @assert !any(y->y===x, store.busy)

    debug && debug_store(mfree, store)
    # @info "mfree" i size(x) map(size, store.free) map(size, store.busy)
    return nothing
end

# helpers

function debug_store(fun, store)
    free = length(store.free)
    busy = length(store.busy)
    @info string(fun) free busy
end

@inline function get_store(smart::SmartAllocator, x::AbstractArray{T,N}) where {T,N}
    A = similar_type(x)
    get!(smart.stores, hash(A)) do 
        ArrayStore{A}(A[], A[])
    end :: ArrayStore{A} # for type stability
end

@generated function similar_type(::A) where {T, N, A<:AbstractArray{T,N}}
    return typeof(similar(A, ntuple(i->0, Val(N))))
end

end # module

