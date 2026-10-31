%% Vectors of three floats, also used for colours (as r, g and b).
-module(rt_vec3).

-export([
    add/2,
    sub/2,
    mul/2,
    scale/2,
    divide/2,
    neg/1,
    dot/2,
    cross/2,
    norm/1,
    unit/1,
    random_in_unit_sphere/1,
    random_in_unit_disk/1
]).
-export_type([vec3/0]).

-type vec3() :: {float(), float(), float()}.

%% The guards tell the compiler that the components are floats, so that the
%% JIT can use float instructions instead of arithmetic that checks the types
%% of its operands.
-define(FLOATS(X, Y, Z), is_float(X), is_float(Y), is_float(Z)).

-spec add(vec3(), vec3()) -> vec3().
add({AX, AY, AZ}, {BX, BY, BZ}) when ?FLOATS(AX, AY, AZ), ?FLOATS(BX, BY, BZ) ->
    {AX + BX, AY + BY, AZ + BZ}.

-spec sub(vec3(), vec3()) -> vec3().
sub({AX, AY, AZ}, {BX, BY, BZ}) when ?FLOATS(AX, AY, AZ), ?FLOATS(BX, BY, BZ) ->
    {AX - BX, AY - BY, AZ - BZ}.

%% Component-wise multiplication.
-spec mul(vec3(), vec3()) -> vec3().
mul({AX, AY, AZ}, {BX, BY, BZ}) when ?FLOATS(AX, AY, AZ), ?FLOATS(BX, BY, BZ) ->
    {AX * BX, AY * BY, AZ * BZ}.

-spec scale(float(), vec3()) -> vec3().
scale(S, {X, Y, Z}) when is_float(S), ?FLOATS(X, Y, Z) ->
    {S * X, S * Y, S * Z}.

-spec divide(vec3(), float()) -> vec3().
divide({X, Y, Z}, S) when is_float(S), ?FLOATS(X, Y, Z) ->
    {X / S, Y / S, Z / S}.

-spec neg(vec3()) -> vec3().
neg({X, Y, Z}) ->
    {-X, -Y, -Z}.

-spec dot(vec3(), vec3()) -> float().
dot({AX, AY, AZ}, {BX, BY, BZ}) when ?FLOATS(AX, AY, AZ), ?FLOATS(BX, BY, BZ) ->
    AX * BX + AY * BY + AZ * BZ.

-spec cross(vec3(), vec3()) -> vec3().
cross({AX, AY, AZ}, {BX, BY, BZ}) ->
    {AY * BZ - AZ * BY, AZ * BX - AX * BZ, AX * BY - AY * BX}.

-spec norm(vec3()) -> float().
norm(V) ->
    math:sqrt(dot(V, V)).

-spec unit(vec3()) -> vec3().
unit(V) ->
    divide(V, norm(V)).

%% Rejection sampling: picks points in the enclosing cube until one lands
%% inside.
-spec random_in_unit_sphere(rt_rng:rng()) -> {vec3(), rt_rng:rng()}.
random_in_unit_sphere(Rng0) ->
    {X, Rng1} = coord(Rng0),
    {Y, Rng2} = coord(Rng1),
    {Z, Rng3} = coord(Rng2),
    case X * X + Y * Y + Z * Z < 1.0 of
        true -> {{X, Y, Z}, Rng3};
        false -> random_in_unit_sphere(Rng3)
    end.

-spec random_in_unit_disk(rt_rng:rng()) -> {vec3(), rt_rng:rng()}.
random_in_unit_disk(Rng0) ->
    {X, Rng1} = coord(Rng0),
    {Y, Rng2} = coord(Rng1),
    case X * X + Y * Y < 1.0 of
        true -> {{X, Y, 0.0}, Rng2};
        false -> random_in_unit_disk(Rng2)
    end.

coord(Rng0) ->
    {F, Rng} = rt_rng:uniform(Rng0),
    {2.0 * F - 1.0, Rng}.
