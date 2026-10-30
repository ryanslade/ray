(* Just what the closest-hit loop needs from each sphere. A record of only
   floats stores them unboxed, so they're one pointer away rather than two. *)
type bound = { cx : float; cy : float; cz : float; radius_squared : float }
type t = { spheres : Sphere.t array; bounds : bound array }

let of_list l =
  let spheres = Array.of_list l in
  let bound ({ center = { x; y; z }; radius; _ } : Sphere.t) =
    { cx = x; cy = y; cz = z; radius_squared = radius *. radius }
  in
  { spheres; bounds = Array.map bound spheres }

(* Returns the closest hit, shrinking [t_max] as nearer objects are found. This
   is [Sphere.intersect] on each sphere in turn, with the same arithmetic, but
   with everything that depends only on the ray worked out once. *)
let hit world (ray : Ray.t) ~t_min ~t_max =
  let { Vec3.x = rox; y = roy; z = roz } = ray.origin
  and { Vec3.x = dx; y = dy; z = dz } = ray.direction in
  let a = (dx *. dx) +. (dy *. dy) +. (dz *. dz) in
  (* Only the hit record for the closest sphere is ever needed, so just track
     which one it is until the end. *)
  let closest = ref (-1) and closest_t = ref t_max in
  let bounds = world.bounds in
  for i = 0 to Array.length bounds - 1 do
    let s = bounds.(i) in
    let ox = rox -. s.cx and oy = roy -. s.cy and oz = roz -. s.cz in
    let b = (ox *. dx) +. (oy *. dy) +. (oz *. dz) in
    let c = (ox *. ox) +. (oy *. oy) +. (oz *. oz) -. s.radius_squared in
    let discriminant = (b *. b) -. (a *. c) in
    (* Most rays miss most spheres. *)
    if discriminant >= 0. then begin
      let sqrt_d = sqrt discriminant in
      let near = (-.b -. sqrt_d) /. a in
      if near < !closest_t && near > t_min then (
        closest := i;
        closest_t := near)
      else
        let far = (-.b +. sqrt_d) /. a in
        if far < !closest_t && far > t_min then (
          closest := i;
          closest_t := far)
    end
  done;
  if !closest < 0 then None
  else Some (Sphere.hit_at world.spheres.(!closest) ray !closest_t)
