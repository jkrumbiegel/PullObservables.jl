using PullObservables
using Test

@testset "PullObservables.jl" begin
    a = PullObservable(1)
    b = PullObservable(2)
    c = PullObservable{Union{Nothing,Int}}(nothing)
  
    @test c[] === nothing
    @test !PullObservables.is_invalid(c)
  
    map!(c, a, b) do a, b
      a + b
    end
    @test PullObservables.is_invalid(c)
    @test c[] === 3
    @test c.val === 3
  
    @test_throws ErrorException c[] = nothing # not allowed to mutate observables that depend on others
  
    a[] = 4
    @test !PullObservables.is_invalid(a)
    @test !PullObservables.is_invalid(b)
    @test PullObservables.is_invalid(c)
    @test c[] === 6
  
    d = PullObservable{Union{Nothing,Int}}(nothing)
    e = PullObservable{Union{Nothing,Int}}(nothing)
  
    map!(d, c) do c
      c * 2
    end
    map!(e, d) do d
      -d
    end
    @test PullObservables.is_invalid(d)
    @test PullObservables.is_invalid(e)
    @test !PullObservables.is_invalid(c)
  
    @test e[] === -12
    @test !PullObservables.is_invalid(e)
    @test !PullObservables.is_invalid(d)
    @test d.val === 12
  
    # Direct mutation should of the `value` field should not be done, but here just
    # simulates a mutation of the value held by a PullObservable which could be some more complex object.
    # At this point in time, if one forgets to call `notify`, the chain is in inconsistent state.
    b.val = 3
    @test !PullObservables.is_invalid(c) # c doesn't know about the mutation
    @test !PullObservables.is_invalid(d)
    @test !PullObservables.is_invalid(e)
    PullObservables.notify(b)
    @test PullObservables.is_invalid(c)
    @test PullObservables.is_invalid(d)
    @test PullObservables.is_invalid(e)
  
    @test e[] === -14
    @test d.val === 14
    @test c.val === 7
  
    @test_throws ErrorException PullObservables.notify(c) # not allowed to notify an observable with dependency
  
    # change e to depend on a directly, this removes the previous mapping
    @test d.dependents == [e]
    map!(e, a) do a
      a^2
    end
    @test isempty(d.dependents)
    @test PullObservables.is_invalid(e)
    @test !PullObservables.is_invalid(a)
    @test !PullObservables.is_invalid(c)
    @test !PullObservables.is_invalid(d)
    @test e[] === 16
  
    # now update two separate chains going off from a
    a[] = 3
    @test !PullObservables.is_invalid(a)
    @test PullObservables.is_invalid(c)
    @test PullObservables.is_invalid(d)
    @test PullObservables.is_invalid(e)
  
    # requesting e does not influence c and d anymore
    @test e[] === 9
    @test !PullObservables.is_invalid(e)
    @test PullObservables.is_invalid(c)
    @test PullObservables.is_invalid(d)
  
    # requesting d updates the second chain as before
    @test d[] === 12
    @test !PullObservables.is_invalid(d)
    @test !PullObservables.is_invalid(c)
  
    # initializer
    ini = PullObservable{Int}(; initializer = () -> 1)
    @test PullObservables.is_invalid(ini)
    @test ini[] === 1
  
    ini2 = PullObservable{Int}(; initializer = () -> 1)
    @test PullObservables.is_invalid(ini2)
    ini2[] = 5
    @test !PullObservables.is_invalid(ini2)
    @test ini2[] === 5
  
    # conversion on assign
    x = PullObservable(3.0)
    x[] = 4
    @test x[] === 4.0
  
    # @valid macro
    x = PullObservable{Int}(; initializer = () -> error())
    y = PullObservable{Int}(; initializer = () -> error())
    @test_throws PullObservables.PullObservableUpdateError x[]
    @test_throws PullObservables.PullObservableUpdateError y[]
    @test 1 == @valid x[] 1
    @test 1 == @valid x[] y[] 1
    @test_throws PullObservables.PullObservableUpdateError @valid x[] y[]
  end
