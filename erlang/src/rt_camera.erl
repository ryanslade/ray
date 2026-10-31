-module(rt_camera).

-export([new/1, get_ray/4]).
-export_type([camera/0, settings/0]).

-record(camera, {
    origin :: rt_vec3:vec3(),
    lower_left :: rt_vec3:vec3(),
    horizontal :: rt_vec3:vec3(),
    vertical :: rt_vec3:vec3(),
    u :: rt_vec3:vec3(),
    v :: rt_vec3:vec3(),
    lens_radius :: float()
}).

-opaque camera() :: #camera{}.
%% vfov is the vertical field of view in degrees.
-type settings() :: #{
    look_from := rt_vec3:vec3(),
    look_at := rt_vec3:vec3(),
    v_up := rt_vec3:vec3(),
    vfov := float(),
    aspect := float(),
    aperture := float(),
    focus_dist := float()
}.

-spec new(settings()) -> camera().
new(#{
    look_from := LookFrom,
    look_at := LookAt,
    v_up := VUp,
    vfov := VFov,
    aspect := Aspect,
    aperture := Aperture,
    focus_dist := FocusDist
}) ->
    %% The same constant as Rust's to_radians.
    Theta = VFov * (math:pi() / 180.0),
    HalfHeight = math:tan(Theta / 2.0),
    HalfWidth = Aspect * HalfHeight,
    W = rt_vec3:unit(rt_vec3:sub(LookFrom, LookAt)),
    U = rt_vec3:unit(rt_vec3:cross(VUp, W)),
    V = rt_vec3:cross(W, U),
    LowerLeft = lists:foldl(
        fun(Step, P) -> rt_vec3:sub(P, Step) end,
        LookFrom,
        [
            rt_vec3:scale(HalfWidth * FocusDist, U),
            rt_vec3:scale(HalfHeight * FocusDist, V),
            rt_vec3:scale(FocusDist, W)
        ]
    ),
    #camera{
        origin = LookFrom,
        lower_left = LowerLeft,
        horizontal = rt_vec3:scale(2.0 * HalfWidth * FocusDist, U),
        vertical = rt_vec3:scale(2.0 * HalfHeight * FocusDist, V),
        u = U,
        v = V,
        lens_radius = Aperture / 2.0
    }.

%% A ray through the viewport at normalised coordinates (S, T), with its
%% origin jittered across the lens.
-spec get_ray(camera(), float(), float(), rt_rng:rng()) -> {rt_ray:ray(), rt_rng:rng()}.
get_ray(
    #camera{
        origin = Origin,
        lower_left = LowerLeft,
        horizontal = Horizontal,
        vertical = Vertical,
        u = U,
        v = V,
        lens_radius = LensRadius
    },
    S,
    T,
    Rng0
) ->
    {Disk, Rng} = rt_vec3:random_in_unit_disk(Rng0),
    {RX, RY, _} = rt_vec3:scale(LensRadius, Disk),
    Offset = rt_vec3:add(rt_vec3:scale(RX, U), rt_vec3:scale(RY, V)),
    Target = rt_vec3:add(
        rt_vec3:add(LowerLeft, rt_vec3:scale(S, Horizontal)),
        rt_vec3:scale(T, Vertical)
    ),
    Direction = rt_vec3:sub(rt_vec3:sub(Target, Origin), Offset),
    {{rt_vec3:add(Origin, Offset), Direction}, Rng}.
