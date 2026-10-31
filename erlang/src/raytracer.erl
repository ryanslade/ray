%% Renders the example scene: `raytracer [output.png]`.
-module(raytracer).

-export([main/1, random_world/1]).

-define(WIDTH, 800).
-define(HEIGHT, 450).
-define(SAMPLES, 100).

-spec main([string()]) -> no_return().
main(Args) ->
    Output =
        case Args of
            [Path | _] -> Path;
            [] -> "out.png"
        end,
    io:format(standard_error, "Generating world~n", []),
    World = random_world(rt_rng:new(1)),
    LookFrom = {3.0, 2.0, 3.0},
    LookAt = {0.0, 0.0, -1.0},
    Camera = rt_camera:new(#{
        look_from => LookFrom,
        look_at => LookAt,
        v_up => {0.0, 1.0, 0.0},
        vfov => 90.0,
        aspect => ?WIDTH / ?HEIGHT,
        aperture => 0.01,
        focus_dist => rt_vec3:norm(rt_vec3:sub(LookFrom, LookAt))
    }),
    io:format(standard_error, "Rendering on ~B schedulers~n", [
        erlang:system_info(schedulers_online)
    ]),
    Img = rt_render:render(?WIDTH, ?HEIGHT, ?SAMPLES, Camera, World),
    case rt_image:save_png(Img, Output) of
        ok ->
            io:format(standard_error, "Wrote ~ts~n", [Output]),
            halt(0);
        {error, Reason} ->
            io:format(standard_error, "Writing ~ts: ~ts~n", [Output, file:format_error(Reason)]),
            halt(1)
    end.

-spec random_world(rt_rng:rng()) -> rt_world:world().
random_world(Rng) ->
    Ground = rt_sphere:new({0.0, -1000.0, -1.0}, 1000.0, rt_material:lambertian({0.5, 0.5, 0.5})),
    Grid = [{A, B} || A <- lists:seq(-11, 10), B <- lists:seq(-11, 10)],
    %% Folded rather than mapped, to pass the generator from each sphere to
    %% the next.
    {SmallSpheres, _} = lists:foldl(
        fun({A, B}, {Spheres, Rng0}) ->
            case small_sphere(A, B, Rng0) of
                {none, Rng1} -> {Spheres, Rng1};
                {Sphere, Rng1} -> {[Sphere | Spheres], Rng1}
            end
        end,
        {[], Rng},
        Grid
    ),
    LargeSpheres = [
        rt_sphere:new({4.0, 1.0, 0.0}, 1.0, rt_material:metal({0.8, 0.6, 0.2}, 0.1)),
        rt_sphere:new({0.0, 1.0, 0.0}, 1.0, rt_material:dielectric(1.5)),
        rt_sphere:new({-4.0, 1.0, 0.0}, 1.0, rt_material:metal({0.8, 0.8, 0.8}, 0.2))
    ],
    rt_world:new([Ground | lists:reverse(SmallSpheres, LargeSpheres)]).

%% A small sphere in the grid square at (A, B), or none if it would be too
%% close to the metal sphere.
small_sphere(A, B, Rng0) ->
    {DX, Rng1} = rt_rng:uniform(Rng0),
    {DZ, Rng2} = rt_rng:uniform(Rng1),
    Center = {A + 0.9 * DX, 0.2, B + 0.9 * DZ},
    case rt_vec3:norm(rt_vec3:sub(Center, {4.0, 0.2, 0.0})) > 0.9 of
        true ->
            {R, Rng3} = channel(Rng2),
            {G, Rng4} = channel(Rng3),
            {Bl, Rng5} = channel(Rng4),
            {rt_sphere:new(Center, 0.2, rt_material:lambertian({R, G, Bl})), Rng5};
        false ->
            {none, Rng2}
    end.

channel(Rng0) ->
    {X, Rng1} = rt_rng:uniform(Rng0),
    {Y, Rng2} = rt_rng:uniform(Rng1),
    {X * Y, Rng2}.
