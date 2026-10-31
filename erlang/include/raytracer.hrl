-record(sphere, {
    center :: rt_vec3:vec3(),
    radius :: float(),
    material :: rt_material:material()
}).

%% Where a ray meets a sphere.
-record(hit, {
    t :: float(),
    point :: rt_vec3:vec3(),
    normal :: rt_vec3:vec3(),
    material :: rt_material:material()
}).

%% The largest finite float, which Rust calls f64::MAX. Erlang floats are
%% never infinite, so it stands in for infinity too.
-define(MAX_FLOAT, 1.7976931348623157e308).
