type t = { center : Vec3.t; radius : float; material : Material.t }

let make center radius material = { center; radius; material }

let hit s (ray : Ray.t) ~t_min ~t_max =
  let oc = Vec3.(ray.origin - s.center) in
  let a = Vec3.dot ray.direction ray.direction in
  let b = Vec3.dot oc ray.direction in
  let c = Vec3.dot oc oc -. (s.radius *. s.radius) in
  let discriminant = (b *. b) -. (a *. c) in
  if discriminant < 0. then None
  else
    let record t =
      let point = Ray.at ray t in
      let normal = Vec3.((point - s.center) / s.radius) in
      Some { Hit.t; point; normal; material = s.material }
    in
    let sqrt_d = sqrt discriminant in
    let in_range t = t < t_max && t > t_min in
    let near = (-.b -. sqrt_d) /. a in
    if in_range near then record near
    else
      let far = (-.b +. sqrt_d) /. a in
      if in_range far then record far else None
