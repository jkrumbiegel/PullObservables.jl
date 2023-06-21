using PullObservables
using Documenter

DocMeta.setdocmeta!(PullObservables, :DocTestSetup, :(using PullObservables); recursive=true)

makedocs(;
    modules=[PullObservables],
    authors="Julius Krumbiegel <julius.krumbiegel@gmail.com> and contributors",
    repo="https://github.com/jkrumbiegel/PullObservables.jl/blob/{commit}{path}#{line}",
    sitename="PullObservables.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://jkrumbiegel.github.io/PullObservables.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/jkrumbiegel/PullObservables.jl",
    devbranch="main",
)
