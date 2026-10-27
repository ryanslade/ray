type t =
  | Lambertian of Color.t
  | Metal of Color.t * float
  | Dielectric of float

(* [fuzz] is clamped to [0, 1]: 0 is a perfect mirror. *)
let metal ?(fuzz = 0.) albedo = Metal (albedo, Float.min 1. (Float.max 0. fuzz))
let reflect v n = Vec3.(v - (2. *. dot v n * n))

let refract v n ni_over_nt =
  let uv = Vec3.unit v in
  let dt = Vec3.dot uv n in
  let discriminant = 1. -. (ni_over_nt *. ni_over_nt *. (1. -. (dt *. dt))) in
  if discriminant > 0. then
    Some Vec3.((ni_over_nt * (uv - (dt * n))) - (sqrt discriminant * n))
  else None

(* Schlick's approximation for reflectance at a given angle. *)
let schlick cosine ref_index =
  let r0 = (1. -. ref_index) /. (1. +. ref_index) in
  let r0 = r0 *. r0 in
  r0 +. ((1. -. r0) *. Float.pow (1. -. cosine) 5.)

let scatter material (ray_in : Ray.t) ~(point : Vec3.t) ~(normal : Vec3.t) st =
  let scattered albedo direction =
    Some (albedo, { Ray.origin = point; direction })
  in
  match material with
  | Lambertian albedo ->
      scattered albedo Vec3.(point + normal + random_in_unit_sphere st - point)
  | Metal (albedo, fuzz) ->
      let reflected = reflect (Vec3.unit ray_in.direction) normal in
      let direction = Vec3.(reflected + (fuzz * random_in_unit_sphere st)) in
      if Vec3.dot direction normal > 0. then scattered albedo direction
      else None
  | Dielectric ref_index ->
      let d = ray_in.direction in
      let d_dot_n = Vec3.dot d normal in
      let outward_normal, ni_over_nt, cosine =
        if d_dot_n > 0. then
          (Vec3.(-normal), ref_index, ref_index *. d_dot_n /. Vec3.length d)
        else (normal, 1. /. ref_index, -.d_dot_n /. Vec3.length d)
      in
      scattered Color.white
        (match refract d outward_normal ni_over_nt with
        | Some refracted
          when Random.State.float st 1. >= schlick cosine ref_index ->
            refracted
        | _ -> reflect d normal)
