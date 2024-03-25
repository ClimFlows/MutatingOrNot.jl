using MutatingOrNot
using Documenter

DocMeta.setdocmeta!(MutatingOrNot, :DocTestSetup, :(using MutatingOrNot); recursive=true)

makedocs(;
    modules=[MutatingOrNot],
    authors="The ClimFlows contributors",
    sitename="MutatingOrNot.jl",
    format=Documenter.HTML(;
        canonical="https://ClimFlows.github.io/MutatingOrNot.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/ClimFlows/MutatingOrNot.jl",
    devbranch="main",
)
