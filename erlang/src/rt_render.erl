-module(rt_render).

-include("raytracer.hrl").

-export([ray_color/3, render/5, render/6]).

-define(MAX_DEPTH, 50).
-define(BLACK, {0.0, 0.0, 0.0}).
-define(WHITE, {1.0, 1.0, 1.0}).
-define(SKY_BLUE, {0.5, 0.7, 1.0}).

%% The colour seen along a ray, following up to 50 bounces.
-spec ray_color(rt_world:world(), rt_vec3:ray(), rt_rng:rng()) -> {rt_vec3:vec3(), rt_rng:rng()}.
ray_color(World, Ray, Rng) ->
    bounce(World, Ray, ?WHITE, 0, Rng).

%% Attenuation is the product of the attenuations of every surface hit so
%% far.
bounce(World, Ray, Attenuation, Depth, Rng0) ->
    case rt_world:hit(World, Ray, 0.001, ?MAX_FLOAT) of
        none ->
            {rt_vec3:mul(Attenuation, sky(Ray)), Rng0};
        _ when Depth =:= ?MAX_DEPTH ->
            {?BLACK, Rng0};
        #hit{material = Material} = Hit ->
            case rt_material:scatter(Material, Ray, Hit, Rng0) of
                {scattered, A, Scattered, Rng} ->
                    bounce(World, Scattered, rt_vec3:mul(Attenuation, A), Depth + 1, Rng);
                {absorbed, Rng} ->
                    {?BLACK, Rng}
            end
    end.

sky({_Origin, Direction}) ->
    {_, Y, _} = rt_vec3:unit(Direction),
    T = 0.5 * (Y + 1.0),
    rt_vec3:add(rt_vec3:scale(1.0 - T, ?WHITE), rt_vec3:scale(T, ?SKY_BLUE)).

%% Renders the world with Samples rays per pixel, by one process per
%% scheduler (so one per core).
-spec render(
    non_neg_integer(), non_neg_integer(), pos_integer(), rt_camera:camera(), rt_world:world()
) -> rt_image:image().
render(Width, Height, Samples, Camera, World) ->
    render(Width, Height, Samples, Camera, World, erlang:system_info(schedulers_online)).

%% Like render/5, but by Workers processes. Each row uses its own random
%% state seeded from the row index, so the image is identical whatever the
%% number of workers.
-spec render(
    non_neg_integer(),
    non_neg_integer(),
    pos_integer(),
    rt_camera:camera(),
    rt_world:world(),
    pos_integer()
) -> rt_image:image().
render(Width, Height, Samples, Camera, World, Workers) when Workers > 0 ->
    Parent = self(),
    Ref = make_ref(),
    RenderRow = fun(Y) -> render_row(Y, Width, Height, Samples, Camera, World) end,
    Count = min(Workers, Height),
    _ = [spawn_link(fun() -> work(Parent, Ref, RenderRow, none) end) || _ <- lists:seq(1, Count)],
    Rows = dispatch(Ref, lists:seq(0, Height - 1), Count, #{}),
    Pixels = [maps:get(Y, Rows) || Y <- lists:seq(0, Height - 1)],
    rt_image:from_pixels(Width, Height, iolist_to_binary(Pixels)).

%% A worker sends back each row it renders and asks for the next one. Rows
%% vary a lot in cost (sky is cheap, spheres are expensive), so they are
%% handed out one at a time rather than as a fixed share up front.
work(Parent, Ref, RenderRow, Result) ->
    Parent ! {Ref, self(), Result},
    receive
        {Ref, {row, Y}} -> work(Parent, Ref, RenderRow, {Y, RenderRow(Y)});
        {Ref, stop} -> ok
    end.

%% Hands out rows as workers become free, until every worker has stopped.
dispatch(_Ref, _Ys, 0, Rows) ->
    Rows;
dispatch(Ref, Ys, Active, Rows0) ->
    receive
        {Ref, Pid, Result} ->
            Rows =
                case Result of
                    none -> Rows0;
                    {Y, Row} -> Rows0#{Y => Row}
                end,
            case Ys of
                [Next | Rest] ->
                    Pid ! {Ref, {row, Next}},
                    dispatch(Ref, Rest, Active, Rows);
                [] ->
                    Pid ! {Ref, stop},
                    dispatch(Ref, [], Active - 1, Rows)
            end
    end.

render_row(Y, Width, Height, Samples, Camera, World) ->
    {Row, _Rng} = lists:mapfoldl(
        fun(X, Rng0) ->
            {Sum, Rng} = sample(X, Y, Width, Height, Samples, Camera, World, ?BLACK, Rng0),
            {rt_image:encode(rt_vec3:divide(Sum, float(Samples))), Rng}
        end,
        rt_rng:new(Y + 1),
        lists:seq(0, Width - 1)
    ),
    iolist_to_binary(Row).

%% Adds up N samples of the pixel at (X, Y).
sample(_X, _Y, _Width, _Height, 0, _Camera, _World, Sum, Rng) ->
    {Sum, Rng};
sample(X, Y, Width, Height, N, Camera, World, Sum, Rng0) ->
    {DU, Rng1} = rt_rng:uniform(Rng0),
    {DV, Rng2} = rt_rng:uniform(Rng1),
    U = (X + DU) / Width,
    V = (Height - 1 - Y + DV) / Height,
    {Ray, Rng3} = rt_camera:get_ray(Camera, U, V, Rng2),
    {Color, Rng} = ray_color(World, Ray, Rng3),
    sample(X, Y, Width, Height, N - 1, Camera, World, rt_vec3:add(Sum, Color), Rng).
