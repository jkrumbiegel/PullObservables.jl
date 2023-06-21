module PullObservables

export PullObservable, @valid

struct Dependency{F<:Function}
  f::F
  observables::Tuple
end

struct Invalid end
const invalid = Invalid()

mutable struct PullObservable{T}
  val::Union{Invalid,T}
  dependency::Union{Nothing,Dependency} # what this observable depends on
  dependents::Vector{PullObservable} # other observables that have this one in their dependency
  initializer::Union{Nothing,Function}
  name::String
end

Base.show(io::IO, p::PullObservable{T}) where {T} =
  print(io, "$PullObservable{$T}($(is_invalid(p) ? "#invalid#" : p.val))")

PullObservable(value; initializer=nothing, name="unnamed") =
  PullObservable{typeof(value)}(value, nothing, [], initializer, name)
PullObservable{T}(value; initializer=nothing, name="unnamed") where {T} =
  PullObservable{T}(convert(T, value), nothing, [], initializer, name)
PullObservable{T}(; initializer=nothing, name="unnamed") where {T} =
  PullObservable{T}(invalid, nothing, [], initializer, name)

is_invalid(p::PullObservable) = p.val === invalid

function invalidate_dependents!(p::PullObservable)
  for dependent in p.dependents
    invalidate!(dependent)
  end
  return
end

function invalidate!(p::PullObservable)
  p.val = invalid
  invalidate_dependents!(p)
  return
end

# This function is only meant for leaves of the dependency graph, to be used after their content
# was mutated to some new value which should be marked valid manually. Afterwards, the dependents
# are invalidated and they will recompute using this new value when accessed the next time.
function notify(p::PullObservable)
  p.dependency === nothing || error("Tried to `notify` a PullObservable with dependency.")
  invalidate_dependents!(p)
  return
end

function delete_dependency!(p::PullObservable)
  p.dependency === nothing && return
  for observable in p.dependency.observables
    filter!(!=(p), observable.dependents)
  end
  p.dependency = nothing
  return
end

function set_dependency!(p::PullObservable, d::Dependency)
  for observable in d.observables
    push!(observable.dependents, p)
  end
  p.dependency = d
  return
end

function Base.map!(f, p::PullObservable, ps::PullObservable...)
  delete_dependency!(p)
  dependency = Dependency(f, ps)
  set_dependency!(p, dependency)
  invalidate!(p)
  return
end

function validate_dependency!(p::PullObservable)
  is_invalid(p) || return
  if p.dependency === nothing
    if p.initializer === nothing
      error(
        """
        Tried to validate an invalid PullObservable that has no dependencies and no initializer.
        This might have happened because the observable was created as invalid and never `map!`ped.
        """,
      )
    else
      new_value = p.initializer()
      if new_value === invalid
        error(
          "An initializer returned `invalid`. This is not allowed, `invalid` is an internal sentinel value.",
        )
      end
    end
  else
    # this effectively recomputes all invalid dependencies recursively
    dependency_values = map(getindex, p.dependency.observables)
    new_value = p.dependency.f(dependency_values...)
    if new_value === invalid
      error(
        "A new PullObservable value was computed from its dependency as `invalid`. This is not allowed, `invalid` is an internal sentinel value.",
      )
    end
  end
  p.val = new_value
  return
end

element_type(p::PullObservable{T}) where {T} = T

struct PullObservableUpdateError <: Exception
  names::Vector{String}
  originalerr
  originaltrace
end

"""
    @valid expr exprs...


"""
macro valid(expr, exprs...)
  isempty(exprs) && error("At least two expressions must be given")

  function try_block(expr, rest)
    resultvar = gensym()
    if isempty(rest) 
      esc(expr)
    else
      quote
        local $resultvar
        try
          $resultvar = $(esc(expr))
        catch e
          if e isa PullObservableUpdateError
            $resultvar = $(try_block(rest[1], rest[2:end]))
          else
            rethrow(e)
          end
        end
        $resultvar
      end
    end
  end

  try_block(expr, exprs)
end

function Base.showerror(io::IO, p::PullObservableUpdateError)
  print(io, "PullObservableUpdateError: PullObservable ")
  printstyled(io, first(p.names), bold = true)
  println(io, " failed to update")
  if length(p.names) > 1
    for child in p.names[2:end]
      print(io, "  because it depended on ")
      printstyled(io, child, bold = true)
      println(io, " which failed to update")
    end
  end
  print(io, "The cause of the failing update of ")
  printstyled(io, p.names[end]; bold = true)
  println(io, " was:")
  proc = Base.process_backtrace(p.originaltrace)
  keep_to = something(findfirst(x -> x[1].func === :validate_dependency!, proc), length(proc))
  println(io)
  Base.showerror(io, p.originalerr)
  println(io)
  Base.show_backtrace(io, proc[1:keep_to])
  println(io, "\n\nThe trace until the failing update of $(repr(p.names[1])) was:")
end

function Base.getindex(p::PullObservable)
  local err
  local bt
  errored = false
  try
    validate_dependency!(p)
  catch e
    bt = catch_backtrace()
    err = e
    errored = true
  end
  if errored
    names = err isa PullObservableUpdateError ? err.names : String[]
    bt = err isa PullObservableUpdateError ? err.originaltrace : bt
    err = err isa PullObservableUpdateError ? err.originalerr : err
    throw(PullObservableUpdateError([p.name; names], err, bt))
  end
  return p.val
end

function Base.setindex!(p::PullObservable{T}, value) where {T}
  p.dependency === nothing || error(
    "Cannot set a value for a PullObservable with a dependency. Such observables are only allowed to compute their values dynamically from the dependency when requested.",
  )
  if value === invalid
    error(
      "You may not set a `PullObservable` to the value `invalid`. This is not allowed, `invalid` is an internal sentinel value. Call `invalidate!(pullobs)` instead.",
    )
  end
  # we need to convert manually because the value field has a Union type
  p.val = convert(T, value)
  invalidate_dependents!(p)
  return
end

end
