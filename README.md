# MutatingOrNot

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://ClimFlows.github.io/MutatingOrNot.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://ClimFlows.github.io/MutatingOrNot.jl/dev/)
[![Build Status](https://github.com/ClimFlows/MutatingOrNot.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ClimFlows/MutatingOrNot.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/ClimFlows/MutatingOrNot.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/ClimFlows/MutatingOrNot.jl)

## Installation

`MutatingOrNot` is registered in the ClimFlows registry. [Follow instructions there](https://github.com/ClimFlows/JuliaRegistry), then:
```julia
] add MutatingOrNot
```
## Example

```julia
using MutatingOrNot: void

# one implementation for both styles
f!(y, x) = @. y=x^2

# non-mutating style, AD-compatible
x = randn(10)
y = f!(void, x)

# mutating style, non-allocating and possibly more efficient
f!(y, x)
```
