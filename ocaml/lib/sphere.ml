type t = { center : Vec3.t; radius : float; material : Material.t }

let make center radius material = { center; radius; material }

(* The nearest t in ([t_min], [t_max]) at which the ray meets the sphere, or nan
   if there is none. It works on plain floats rather than vectors and options
   so that, once inlined, it allocates nothing: it runs for every ray/sphere
   pair. *)
let[@inline] intersect s (ray : Ray.t) ~t_min ~t_max =
  let o = ray.origin and d = ray.direction in
  let ox = o.x -. s.center.x
  and oy = o.y -. s.center.y
  and oz = o.z -. s.center.z in
  let a = (d.x *. d.x) +. (d.y *. d.y) +. (d.z *. d.z) in
  let b = (ox *. d.x) +. (oy *. d.y) +. (oz *. d.z) in
  let c = (ox *. ox) +. (oy *. oy) +. (oz *. oz) -. (s.radius *. s.radius) in
  let discriminant = (b *. b) -. (a *. c) in
  if discriminant < 0. then Float.nan
  else
    let sqrt_d = sqrt discriminant in
    let near = (-.b -. sqrt_d) /. a in
    if near < t_max && near > t_min then near
    else
      let far = (-.b +. sqrt_d) /. a in
      if far < t_max && far > t_min then far else Float.nan

(* The hit record for a t returned by [intersect]. *)
let hit_at s ray t =
  let point = Ray.at ray t in
  let normal = Vec3.((point - s.center) / s.radius) in
  { Hit.t; point; normal; material = s.material }

let hit s ray ~t_min ~t_max =
  let t = intersect s ray ~t_min ~t_max in
  if Float.is_nan t then None else Some (hit_at s ray t)
