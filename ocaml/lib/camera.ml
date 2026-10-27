(* A camera is a function from normalised viewport coordinates [(s, t)] to a ray
   through them, with its origin jittered across the lens. [vfov] is the
   vertical field of view in degrees. *)
type t = float -> float -> Random.State.t -> Ray.t

let make ~look_from ~look_at ~v_up ~vfov ~aspect ~aperture ~focus_dist : t =
  let half_height = tan (vfov *. Float.pi /. 360.) in
  let half_width = aspect *. half_height in
  let w = Vec3.(unit (look_from - look_at)) in
  let u = Vec3.(unit (cross v_up w)) in
  let v = Vec3.cross w u in
  let lower_left =
    Vec3.(
      look_from
      - (half_width *. focus_dist * u)
      - (half_height *. focus_dist * v)
      - (focus_dist * w))
  in
  let horizontal = Vec3.(2. *. half_width *. focus_dist * u) in
  let vertical = Vec3.(2. *. half_height *. focus_dist * v) in
  let lens_radius = aperture /. 2. in
  fun s t st ->
    let rd = Vec3.random_in_unit_disk st in
    let offset = Vec3.((lens_radius *. rd.x * u) + (lens_radius *. rd.y * v)) in
    {
      origin = Vec3.(look_from + offset);
      direction =
        Vec3.(
          lower_left + (s * horizontal) + (t * vertical) - look_from - offset);
    }
