type t = {
  origin : Vec3.t;
  lower_left : Vec3.t;
  horizontal : Vec3.t;
  vertical : Vec3.t;
  u : Vec3.t;
  v : Vec3.t;
  lens_radius : float;
}

let make ~look_from ~look_at ~v_up ~vfov ~aspect ~aperture ~focus_dist =
  let theta = vfov *. Float.pi /. 180. in
  let half_height = tan (theta /. 2.) in
  let half_width = aspect *. half_height in
  let w = Vec3.(unit (look_from - look_at)) in
  let u = Vec3.(unit (cross v_up w)) in
  let v = Vec3.cross w u in
  Vec3.
    {
      origin = look_from;
      lower_left =
        look_from
        - (half_width *. focus_dist * u)
        - (half_height *. focus_dist * v)
        - (focus_dist * w);
      horizontal = 2. *. half_width *. focus_dist * u;
      vertical = 2. *. half_height *. focus_dist * v;
      u;
      v;
      lens_radius = aperture /. 2.;
    }

let get_ray c s t st =
  let rd = Vec3.random_in_unit_disk st in
  let offset =
    Vec3.((c.lens_radius *. rd.x * c.u) + (c.lens_radius *. rd.y * c.v))
  in
  {
    Ray.origin = Vec3.(c.origin + offset);
    direction =
      Vec3.(
        c.lower_left + (s * c.horizontal) + (t * c.vertical) - c.origin - offset);
  }
