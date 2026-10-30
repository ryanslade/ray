(* The operators are meant for a local open, e.g. [Vec3.(a + (2. * b))]. *)
type t = { x : float; y : float; z : float }

let[@inline] make x y z = { x; y; z }
let zero = make 0. 0. 0.
let[@inline] ( + ) a b = { x = a.x +. b.x; y = a.y +. b.y; z = a.z +. b.z }
let[@inline] ( - ) a b = { x = a.x -. b.x; y = a.y -. b.y; z = a.z -. b.z }
let[@inline] ( * ) s v = { x = s *. v.x; y = s *. v.y; z = s *. v.z }
let[@inline] ( / ) v s = { x = v.x /. s; y = v.y /. s; z = v.z /. s }
let[@inline] ( ~- ) v = { x = -.v.x; y = -.v.y; z = -.v.z }
let[@inline] dot a b = (a.x *. b.x) +. (a.y *. b.y) +. (a.z *. b.z)

let[@inline] cross a b =
  make
    ((a.y *. b.z) -. (a.z *. b.y))
    ((a.z *. b.x) -. (a.x *. b.z))
    ((a.x *. b.y) -. (a.y *. b.x))

let[@inline] length_squared v = dot v v
let[@inline] length v = sqrt (length_squared v)
let[@inline] unit v = v / length v
let[@inline] coord st = (2. *. Random.State.float st 1.) -. 1.

(* Rejection sampling: pick points in the enclosing cube (or square, when [z] is
   false) until one lands inside. *)
let rec random_in_unit ~z st =
  let x = coord st in
  let y = coord st in
  let w = if z then coord st else 0. in
  (* Only the point that's kept is allocated. *)
  if (x *. x) +. (y *. y) +. (w *. w) < 1. then make x y w
  else random_in_unit ~z st

let random_in_unit_sphere st = random_in_unit ~z:true st
let random_in_unit_disk st = random_in_unit ~z:false st
