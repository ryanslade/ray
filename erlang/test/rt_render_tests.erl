-module(rt_render_tests).

-include_lib("eunit/include/eunit.hrl").

same_image_whatever_the_workers_test() ->
    Camera = rt_scene:camera(40, 30),
    World = rt_scene:world(),
    Render = fun(Workers) -> rt_render:render(40, 30, 8, Camera, World, Workers) end,
    Expected = Render(1),
    [?assertEqual(Expected, Render(N), N) || N <- [2, 4, 7]].

%% Renders the test scene and compares it with test/golden.ppm.
%%
%% After an intentional change to the output, run with UPDATE_GOLDEN=1 to
%% accept it. On a mismatch the rendered image is written to
%% test/golden.actual.ppm for inspection.
golden_image_test_() ->
    {timeout, 600, fun golden_image/0}.

golden_image() ->
    Img = rt_render:render(200, 200, 100, rt_scene:camera(200, 200), rt_scene:world()),
    Actual = rt_image:to_ppm(Img),
    Dir = filename:dirname(?FILE),
    Golden = filename:join(Dir, "golden.ppm"),
    case os:getenv("UPDATE_GOLDEN") of
        false ->
            {ok, Expected} = file:read_file(Golden),
            case Actual =:= Expected of
                true ->
                    ok;
                false ->
                    Out = filename:join(Dir, "golden.actual.ppm"),
                    ok = file:write_file(Out, Actual),
                    error({golden_mismatch, Golden, wrote, Out})
            end;
        _ ->
            ok = file:write_file(Golden, Actual)
    end.
