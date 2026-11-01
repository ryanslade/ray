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

%% Guards that tell the compiler these are floats, so that the JIT can use
%% float instructions instead of arithmetic that checks the types of its
%% operands, and keep the results unboxed.
-define(FLOATS(X, Y, Z), is_float(X), is_float(Y), is_float(Z)).
