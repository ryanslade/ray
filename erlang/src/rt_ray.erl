-module(rt_ray).

-export([at/2]).
-export_type([ray/0]).

-type ray() :: {Origin :: rt_vec3:vec3(), Direction :: rt_vec3:vec3()}.

-spec at(ray(), float()) -> rt_vec3:vec3().
at({Origin, Direction}, T) ->
    rt_vec3:add(Origin, rt_vec3:scale(T, Direction)).
