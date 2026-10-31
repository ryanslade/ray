%% Materials, as tagged tuples.
-module(rt_material).

-include("raytracer.hrl").

-export([lambertian/1, metal/2, dielectric/1, scatter/4, refract/3]).
-export_type([material/0]).

-type material() ::
    {lambertian, Albedo :: rt_vec3:vec3()}
    | {metal, Albedo :: rt_vec3:vec3(), Fuzz :: float()}
    | {dielectric, RefIndex :: float()}.

-spec lambertian(rt_vec3:vec3()) -> material().
lambertian(Albedo) ->
    {lambertian, Albedo}.

%% Fuzz is clamped to [0, 1]: 0 is a perfect mirror.
-spec metal(rt_vec3:vec3(), float()) -> material().
metal(Albedo, Fuzz) ->
    {metal, Albedo, max(0.0, min(1.0, Fuzz))}.

-spec dielectric(float()) -> material().
dielectric(RefIndex) ->
    {dielectric, RefIndex}.

%% The attenuation and the scattered ray, unless the ray is absorbed.
-spec scatter(material(), rt_ray:ray(), #hit{}, rt_rng:rng()) ->
    {scattered, rt_vec3:vec3(), rt_ray:ray(), rt_rng:rng()} | {absorbed, rt_rng:rng()}.
scatter({lambertian, Albedo}, _RayIn, #hit{point = P, normal = N}, Rng0) ->
    {R, Rng} = rt_vec3:random_in_unit_sphere(Rng0),
    Target = rt_vec3:add(rt_vec3:add(P, N), R),
    {scattered, Albedo, {P, rt_vec3:sub(Target, P)}, Rng};
scatter({metal, Albedo, Fuzz}, {_, D}, #hit{point = P, normal = N}, Rng0) ->
    Reflected = reflect(rt_vec3:unit(D), N),
    {R, Rng} = rt_vec3:random_in_unit_sphere(Rng0),
    Direction = rt_vec3:add(Reflected, rt_vec3:scale(Fuzz, R)),
    case rt_vec3:dot(Direction, N) > 0.0 of
        true -> {scattered, Albedo, {P, Direction}, Rng};
        false -> {absorbed, Rng}
    end;
scatter({dielectric, RefIndex}, {_, D}, #hit{point = P, normal = N}, Rng0) ->
    DDotN = rt_vec3:dot(D, N),
    {OutwardNormal, NiOverNt, Cosine} =
        case DDotN > 0.0 of
            true -> {rt_vec3:neg(N), RefIndex, RefIndex * DDotN / rt_vec3:norm(D)};
            false -> {N, 1.0 / RefIndex, -DDotN / rt_vec3:norm(D)}
        end,
    %% Only draws a random number when the ray can refract.
    {Direction, Rng} =
        case refract(D, OutwardNormal, NiOverNt) of
            {ok, Refracted} ->
                {X, Rng1} = rt_rng:uniform(Rng0),
                case X >= schlick(Cosine, RefIndex) of
                    true -> {Refracted, Rng1};
                    false -> {reflect(D, N), Rng1}
                end;
            none ->
                {reflect(D, N), Rng0}
        end,
    {scattered, {1.0, 1.0, 1.0}, {P, Direction}, Rng}.

reflect(V, N) ->
    rt_vec3:sub(V, rt_vec3:scale(2.0 * rt_vec3:dot(V, N), N)).

%% The refracted direction, or none on total internal reflection.
-spec refract(rt_vec3:vec3(), rt_vec3:vec3(), float()) -> {ok, rt_vec3:vec3()} | none.
refract(V, N, NiOverNt) ->
    UV = rt_vec3:unit(V),
    DT = rt_vec3:dot(UV, N),
    Discriminant = 1.0 - NiOverNt * NiOverNt * (1.0 - DT * DT),
    case Discriminant > 0.0 of
        true ->
            {ok,
                rt_vec3:sub(
                    rt_vec3:scale(NiOverNt, rt_vec3:sub(UV, rt_vec3:scale(DT, N))),
                    rt_vec3:scale(math:sqrt(Discriminant), N)
                )};
        false ->
            none
    end.

%% Schlick's approximation for reflectance at a given angle.
schlick(Cosine, RefIndex) ->
    R0 = (1.0 - RefIndex) / (1.0 + RefIndex),
    R1 = R0 * R0,
    %% Multiplied out rather than using math:pow, whose result can vary by
    %% platform, to match the other versions' golden image.
    X = 1.0 - Cosine,
    X2 = X * X,
    R1 + (1.0 - R1) * X2 * X2 * X.
