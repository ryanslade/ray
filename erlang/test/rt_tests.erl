-module(rt_tests).

-include_lib("eunit/include/eunit.hrl").
-include("raytracer.hrl").

close(A, B) ->
    rt_vec3:norm(rt_vec3:sub(A, B)) < 1.0e-9.

vector_arithmetic_test() ->
    A = {1.0, 2.0, 3.0},
    B = {4.0, 5.0, 6.0},
    ?assert(close({5.0, 7.0, 9.0}, rt_vec3:add(A, B))),
    ?assert(close({2.0, 4.0, 6.0}, rt_vec3:scale(2.0, A))),
    ?assertEqual(32.0, rt_vec3:dot(A, B)),
    ?assert(close({-3.0, 6.0, -3.0}, rt_vec3:cross(A, B))),
    ?assert(abs(rt_vec3:norm(rt_vec3:unit(B)) - 1.0) < 1.0e-9).

floats(N, Rng) ->
    {Floats, _} = lists:mapfoldl(fun(_, R) -> rt_rng:uniform(R) end, Rng, lists:seq(1, N)),
    Floats.

floats_in_unit_interval_test() ->
    ?assert(lists:all(fun(F) -> F >= 0.0 andalso F < 1.0 end, floats(10000, rt_rng:new(1)))).

same_seed_same_sequence_test() ->
    ?assertEqual(floats(100, rt_rng:new(42)), floats(100, rt_rng:new(42))).

matches_splitmix64_test() ->
    %% The first outputs for seed 0 from the reference implementation.
    {A, Rng} = rt_rng:next(rt_rng:new(0)),
    {B, _} = rt_rng:next(Rng),
    ?assertEqual(16#E220A8397B1DCDAF, A),
    ?assertEqual(16#6E789E6AA1B965F4, B).

sphere_hit_test() ->
    S = rt_sphere:new({0.0, 0.0, -1.0}, 0.5, rt_material:dielectric(1.5)),
    Towards = {{0.0, 0.0, 0.0}, {0.0, 0.0, -1.0}},
    ?assertMatch(
        #hit{t = 0.5, normal = {+0.0, +0.0, 1.0}},
        rt_sphere:hit(S, Towards, 0.0, ?MAX_FLOAT)
    ),
    ?assertMatch(#hit{t = 1.5}, rt_sphere:hit(S, Towards, 0.6, ?MAX_FLOAT), "far side"),
    Away = {{0.0, 0.0, 0.0}, {0.0, 1.0, 0.0}},
    ?assertEqual(none, rt_sphere:hit(S, Away, 0.0, ?MAX_FLOAT)).

closest_hit_test() ->
    M = rt_material:dielectric(1.5),
    World = rt_world:new([
        rt_sphere:new({0.0, 0.0, -5.0}, 1.0, M),
        rt_sphere:new({0.0, 0.0, -2.0}, 0.5, M)
    ]),
    ?assertMatch(
        #hit{t = 1.5},
        rt_world:hit(World, {{0.0, 0.0, 0.0}, {0.0, 0.0, -1.0}}, 0.0, ?MAX_FLOAT)
    ),
    ?assertEqual(none, rt_world:hit(World, {{0.0, 0.0, 0.0}, {0.0, 1.0, 0.0}}, 0.0, ?MAX_FLOAT)).

%% rt_world:hit/4 has its own copy of the intersection arithmetic, which must
%% find exactly the hit that rt_sphere:hit/4 on each sphere in turn would.
matches_sphere_by_sphere_test() ->
    Coords = [2.0 * F - 1.0 || F <- floats(23 * 4 + 2000 * 6, rt_rng:new(1))],
    {SphereCoords, RayCoords} = lists:split(23 * 4, Coords),
    M = rt_material:dielectric(1.5),
    Spheres = [
        rt_sphere:new({3.0 * X, 3.0 * Y, 3.0 * Z}, 0.1 + abs(R), M)
     || [X, Y, Z, R] <- chunks(4, SphereCoords)
    ],
    World = rt_world:new(Spheres),
    lists:foreach(
        fun([OX, OY, OZ, DX, DY, DZ]) ->
            Ray = {{5.0 * OX, 5.0 * OY, 5.0 * OZ}, {DX, DY, DZ}},
            {Want, _} = lists:foldl(
                fun(S, {Closest, TMax}) ->
                    case rt_sphere:hit(S, Ray, 0.001, TMax) of
                        none -> {Closest, TMax};
                        #hit{t = T} = Hit -> {Hit, T}
                    end
                end,
                {none, ?MAX_FLOAT},
                Spheres
            ),
            ?assertEqual(Want, rt_world:hit(World, Ray, 0.001, ?MAX_FLOAT))
        end,
        chunks(6, RayCoords)
    ).

chunks(_N, []) ->
    [];
chunks(N, List) ->
    {Chunk, Rest} = lists:split(N, List),
    [Chunk | chunks(N, Rest)].

total_internal_reflection_test() ->
    ?assertEqual(none, rt_material:refract({1.0, -0.1, 0.0}, {0.0, 1.0, 0.0}, 1.5)).

refracts_head_on_test() ->
    Down = {0.0, -1.0, 0.0},
    {ok, R} = rt_material:refract(Down, {0.0, 1.0, 0.0}, 1.0 / 1.5),
    ?assert(close(Down, R)).

metal_fuzz_is_clamped_test() ->
    ?assertMatch({metal, _, 1.0}, rt_material:metal({1.0, 1.0, 1.0}, 2.0)),
    ?assertMatch({metal, _, +0.0}, rt_material:metal({1.0, 1.0, 1.0}, -1.0)).

set_pixel_clamps_test() ->
    Img = rt_image:set_pixel(rt_image:new(3, 1), 1, 0, {2.0, 0.5, -1.0}),
    ?assertEqual({0, 0, 0}, rt_image:pixel(Img, 0, 0)),
    ?assertEqual({255, 127, 0}, rt_image:pixel(Img, 1, 0)),
    ?assertError({out_of_bounds, 3, 0}, rt_image:pixel(Img, 3, 0)).

ppm_header_test() ->
    Ppm = rt_image:to_ppm(rt_image:new(3, 2)),
    ?assertMatch(<<"P6\n3 2\n255\n", _/binary>>, Ppm),
    ?assertEqual(11 + 3 * 2 * 3, byte_size(Ppm)).

%% Splits a PNG into its chunks, as {Type, Data} pairs, checking their CRCs.
png_chunks(<<>>) ->
    [];
png_chunks(<<Len:32, Type:4/binary, Data:Len/binary, Crc:32, Rest/binary>>) ->
    ?assertEqual(erlang:crc32([Type, Data]), Crc),
    [{Type, Data} | png_chunks(Rest)].

png_test() ->
    {W, H} = {20, 12},
    Img = lists:foldl(
        fun({X, Y}, Acc) ->
            rt_image:set_pixel(Acc, X, Y, {X / W, Y / H, ((X + Y) rem 7) / 7})
        end,
        rt_image:new(W, H),
        [{X, Y} || Y <- lists:seq(0, H - 1), X <- lists:seq(0, W - 1)]
    ),
    <<16#89, "PNG\r\n", 16#1A, "\n", Rest/binary>> = rt_image:to_png(Img),
    [{<<"IHDR">>, Header}, {<<"IDAT">>, Data}, {<<"IEND">>, <<>>}] = png_chunks(Rest),
    ?assertEqual(<<W:32, H:32, 8, 2, 0, 0, 0>>, Header),
    Rows = [Row || <<Row:(1 + 3 * W)/binary>> <= zlib:uncompress(Data)],
    ?assertEqual(H, length(Rows)),
    lists:foreach(
        fun({Y, <<Filter, Pixels/binary>>}) ->
            ?assertEqual(0, Filter),
            Got = [{R, G, B} || <<R, G, B>> <= Pixels],
            Want = [rt_image:pixel(Img, X, Y) || X <- lists:seq(0, W - 1)],
            ?assertEqual(Want, Got)
        end,
        lists:enumerate(0, Rows)
    ).
