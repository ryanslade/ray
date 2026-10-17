type t

val make :
  look_from:Vec3.t ->
  look_at:Vec3.t ->
  v_up:Vec3.t ->
  vfov:float ->
  aspect:float ->
  aperture:float ->
  focus_dist:float ->
  t
(** [vfov] is the vertical field of view in degrees. *)

val get_ray : t -> float -> float -> Random.State.t -> Ray.t
(** [get_ray camera s t st] is a ray through the viewport at normalised
    coordinates [(s, t)], with its origin jittered across the lens. *)
