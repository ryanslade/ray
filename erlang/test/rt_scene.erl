%% The scene used by the tests and benchmark, matching the other versions.
-module(rt_scene).

-export([world/0, camera/2]).

-spec world() -> rt_world:world().
world() ->
    rt_world:new([
        rt_sphere:new({0.0, -100.5, -1.0}, 100.0, rt_material:lambertian({0.5, 0.5, 0.5})),
        rt_sphere:new({0.0, 0.0, -1.0}, 1.0, rt_material:metal({0.8, 0.8, 0.8}, 0.2)),
        rt_sphere:new({1.5, 0.0, -1.0}, 1.0, rt_material:dielectric(1.5))
    ]).

-spec camera(pos_integer(), pos_integer()) -> rt_camera:camera().
camera(Width, Height) ->
    LookFrom = {1.0, 1.0, 1.0},
    LookAt = {0.0, 0.0, -1.0},
    rt_camera:new(#{
        look_from => LookFrom,
        look_at => LookAt,
        v_up => {0.0, 1.0, 0.0},
        vfov => 90.0,
        aspect => Width / Height,
        aperture => 0.01,
        focus_dist => rt_vec3:norm(rt_vec3:sub(LookFrom, LookAt))
    }).
