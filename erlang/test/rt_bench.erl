%% Mirrors BenchmarkRender in the Go version: the test scene at 100x100 with
%% 50 samples per pixel, rendered 20 times by default, on every scheduler.
%%
%% Usage: erl -run rt_bench main [Iterations [Workers]]
-module(rt_bench).

-export([main/1]).

-spec main([string()]) -> no_return().
main(Args) ->
    {Iterations, Workers} =
        case [list_to_integer(A) || A <- Args] of
            [] -> {20, erlang:system_info(schedulers_online)};
            [I] -> {I, erlang:system_info(schedulers_online)};
            [I, W] -> {I, W}
        end,
    Camera = rt_scene:camera(100, 100),
    World = rt_scene:world(),
    Run = fun() -> rt_render:render(100, 100, 50, Camera, World, Workers) end,
    %% Warms up, loading the code.
    _ = Run(),
    {Micros, ok} = timer:tc(fun() -> repeat(Run, Iterations) end),
    io:format("~B iterations in ~B processes: ~.2f ms/op~n", [
        Iterations, Workers, Micros / 1000 / Iterations
    ]),
    halt(0).

repeat(_F, 0) ->
    ok;
repeat(F, N) ->
    _ = F(),
    repeat(F, N - 1).
