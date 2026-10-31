%% A small, fast pseudo-random number generator (SplitMix64), the same as
%% the other versions use, so that scenes and renders are identical.
%%
%% The state is immutable: each function returns its result and the new
%% state, which must be passed to the next call.
-module(rt_rng).

-export([new/1, next/1, uniform/1]).
-export_type([rng/0]).

-opaque rng() :: non_neg_integer().

-define(MASK, 16#FFFFFFFFFFFFFFFF).

-spec new(non_neg_integer()) -> rng().
new(Seed) ->
    Seed band ?MASK.

-spec next(rng()) -> {non_neg_integer(), rng()}.
next(State0) ->
    State = (State0 + 16#9E3779B97F4A7C15) band ?MASK,
    Z1 = ((State bxor (State bsr 30)) * 16#BF58476D1CE4E5B9) band ?MASK,
    Z2 = ((Z1 bxor (Z1 bsr 27)) * 16#94D049BB133111EB) band ?MASK,
    {Z2 bxor (Z2 bsr 31), State}.

%% A uniformly distributed float in [0, 1).
-spec uniform(rng()) -> {float(), rng()}.
uniform(Rng0) ->
    {N, Rng} = next(Rng0),
    %% The top 53 bits fill a float's mantissa exactly.
    {(N bsr 11) * (1.0 / (1 bsl 53)), Rng}.
