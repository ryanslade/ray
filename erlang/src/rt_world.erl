-module(rt_world).

-include("raytracer.hrl").

-export([new/1, hit/4]).
-export_type([world/0]).

%% Each sphere's centre and squared radius as plain floats in a flat tuple,
%% with the sphere, so that the closest-hit loop doesn't take apart the
%% sphere and its centre for every ray.
-opaque world() :: [{float(), float(), float(), float(), #sphere{}}].

-spec new([#sphere{}]) -> world().
new(Spheres) ->
    [{X, Y, Z, R * R, S} || #sphere{center = {X, Y, Z}, radius = R} = S <- Spheres].

%% The closest hit in (TMin, TMax), shrinking TMax as nearer spheres are
%% found, or none.
%%
%% This finds the same hit as calling rt_sphere:intersect/4 on each sphere in
%% turn, with the same arithmetic, so renders are unchanged; but it works on
%% plain floats, and only builds the hit record for the closest sphere.
%%
%% The guards tell the compiler that these are floats, as are the results of
%% arithmetic on them, so that the JIT can keep them unboxed in the loop
%% instead of allocating every intermediate result.
-spec hit(world(), rt_ray:ray(), float(), float()) -> #hit{} | none.
hit(Entries, {{OX, OY, OZ}, {DX, DY, DZ}} = Ray, TMin, TMax) when
    is_float(OX),
    is_float(OY),
    is_float(OZ),
    is_float(DX),
    is_float(DY),
    is_float(DZ),
    is_float(TMin),
    is_float(TMax)
->
    A = DX * DX + DY * DY + DZ * DZ,
    case closest(Entries, OX, OY, OZ, DX, DY, DZ, A, TMin, TMax, none) of
        none -> none;
        {Sphere, T} -> rt_sphere:hit_at(Sphere, Ray, T)
    end.

closest([], _OX, _OY, _OZ, _DX, _DY, _DZ, _A, _TMin, _TMax, none) ->
    none;
closest([], _OX, _OY, _OZ, _DX, _DY, _DZ, _A, _TMin, TMax, Sphere) ->
    {Sphere, TMax};
closest([{CX, CY, CZ, RadiusSquared, S} | Rest], OX, OY, OZ, DX, DY, DZ, A, TMin, TMax, Found) when
    is_float(CX), is_float(CY), is_float(CZ), is_float(RadiusSquared)
->
    %% OC is the vector from the sphere's centre to the ray's origin.
    OCX = OX - CX,
    OCY = OY - CY,
    OCZ = OZ - CZ,
    B = OCX * DX + OCY * DY + OCZ * DZ,
    C = OCX * OCX + OCY * OCY + OCZ * OCZ - RadiusSquared,
    Discriminant = B * B - A * C,
    if
        %% Most rays miss most spheres.
        Discriminant < 0.0 ->
            closest(Rest, OX, OY, OZ, DX, DY, DZ, A, TMin, TMax, Found);
        true ->
            SqrtD = math:sqrt(Discriminant),
            Near = (-B - SqrtD) / A,
            Far = (-B + SqrtD) / A,
            if
                Near < TMax, Near > TMin ->
                    closest(Rest, OX, OY, OZ, DX, DY, DZ, A, TMin, Near, S);
                Far < TMax, Far > TMin ->
                    closest(Rest, OX, OY, OZ, DX, DY, DZ, A, TMin, Far, S);
                true ->
                    closest(Rest, OX, OY, OZ, DX, DY, DZ, A, TMin, TMax, Found)
            end
    end.
