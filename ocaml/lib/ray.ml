type t = { origin : Vec3.t; direction : Vec3.t }

let at r t = Vec3.(r.origin + (t * r.direction))
