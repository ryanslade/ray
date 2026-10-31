-module(rt_sphere).

-include("raytracer.hrl").

-export([new/3, intersect/4, hit_at/3, hit/4]).

-spec new(rt_vec3:vec3(), float(), rt_material:material()) -> #sphere{}.
new(Center, Radius, Material) ->
    #sphere{center = Center, radius = Radius, material = Material}.

%% The nearest T in (TMin, TMax) at which the ray meets the sphere, or none.
%% rt_world:hit/4 has its own copy of this arithmetic, which must stay in
%% step with it.
-spec intersect(#sphere{}, rt_ray:ray(), float(), float()) -> float() | none.
intersect(#sphere{center = Center, radius = Radius}, {Origin, Direction}, TMin, TMax) ->
    OC = rt_vec3:sub(Origin, Center),
    A = rt_vec3:dot(Direction, Direction),
    B = rt_vec3:dot(OC, Direction),
    C = rt_vec3:dot(OC, OC) - Radius * Radius,
    Discriminant = B * B - A * C,
    case Discriminant < 0.0 of
        true ->
            none;
        false ->
            SqrtD = math:sqrt(Discriminant),
            Near = (-B - SqrtD) / A,
            Far = (-B + SqrtD) / A,
            if
                Near < TMax, Near > TMin -> Near;
                Far < TMax, Far > TMin -> Far;
                true -> none
            end
    end.

%% The hit record for a T returned by intersect/4.
-spec hit_at(#sphere{}, rt_ray:ray(), float()) -> #hit{}.
hit_at(#sphere{center = Center, radius = Radius, material = Material}, Ray, T) ->
    Point = rt_ray:at(Ray, T),
    Normal = rt_vec3:divide(rt_vec3:sub(Point, Center), Radius),
    #hit{t = T, point = Point, normal = Normal, material = Material}.

-spec hit(#sphere{}, rt_ray:ray(), float(), float()) -> #hit{} | none.
hit(Sphere, Ray, TMin, TMax) ->
    case intersect(Sphere, Ray, TMin, TMax) of
        none -> none;
        T -> hit_at(Sphere, Ray, T)
    end.
