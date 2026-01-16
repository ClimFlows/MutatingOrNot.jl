const debug = false

struct ArrayStore{T,N,A<:AbstractArray{T,N}}
    arrays::Vector{A}
    tags::Vector{Tuple{Bool, NTuple{N, Int}}} # for each array: (free/busy, size)
end

struct SmartAllocator{Dryrun} <: ArrayAllocator
    stores::Dict{UInt64, ArrayStore}
end

has_dryrun(::SmartAllocator{DryRun}) where DryRun = DryRun
set_dryrun(smart::SmartAllocator) = SmartAllocator{true}(stores(smart))
@inline stores(smart) = getfield(smart, :stores) # getproperty is overloaded for ::ArrayAllocator

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
SmartAllocator() = SmartAllocator{false}(Dict{UInt64, ArrayStore}())
Base.empty!(smart::SmartAllocator) = empty!(smart.stores)

# malloc

@inline malloc(smart::SmartAllocator, args...) = malloc_smart(smart, args...) # dispatch
@inline malloc_smart(smart, x) = malloc_smart(smart, x, eltype(x), size(x))
@inline malloc_smart(smart, x, ::Type{T}) where T = malloc_smart(smart, x, T, size(x))

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
