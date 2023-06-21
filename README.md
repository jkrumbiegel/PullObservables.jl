# PullObservables

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://jkrumbiegel.github.io/PullObservables.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jkrumbiegel.github.io/PullObservables.jl/dev/)
[![Build Status](https://github.com/jkrumbiegel/PullObservables.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jkrumbiegel/PullObservables.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/jkrumbiegel/PullObservables.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/jkrumbiegel/PullObservables.jl)

The problems with eager or push updating in [Observables.jl](https://github.com/JuliaGizmos/Observables.jl) are:
- updating multiple observables in sequence fails if they're mapped together and are only valid after all are changed to their new state
- every update traverses the whole computation graph it's connected to, potentially wasting a lot of resources if the result is not used

PullObservables solve these issues by only recomputing their values once requested (pulled).
Here's an example:

```julia
using PullObservables

x = PullObservable([1, 2, 3])
y = PullObservable([4, 5, 6])
z = PullObservable{Vector{Int}}()
map!(z, x, y) do x, y
    println("Computing z")
    x .+ y
end
@show z[]

println("Updating x")
x[] = [1, 2, 3, 4]
println("Updating y")
y[] = [4, 5, 6, 7]
@show z[]
```

```
Computing z
z[] = [5, 7, 9]
Updating x
Updating y
Computing z
z[] = [5, 7, 9, 11]
```
