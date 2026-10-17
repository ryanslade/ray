type t = { x : float; y : float; z : float }

let[@inline] make x y z = { x; y; z }
let zero = make 0. 0. 0.
let[@inline] add a b = { x = a.x +. b.x; y = a.y +. b.y; z = a.z +. b.z }
let[@inline] sub a b = { x = a.x -. b.x; y = a.y -. b.y; z = a.z -. b.z }
let[@inline] scale s v = { x = s *. v.x; y = s *. v.y; z = s *. v.z }
let[@inline] div v s = { x = v.x /. s; y = v.y /. s; z = v.z /. s }
let[@inline] neg v = { x = -.v.x; y = -.v.y; z = -.v.z }
let[@inline] dot a b = (a.x *. b.x) +. (a.y *. b.y) +. (a.z *. b.z)

let[@inline] cross a b =
  {
    x = (a.y *. b.z) -. (a.z *. b.y);
    y = (a.z *. b.x) -. (a.x *. b.z);
    z = (a.x *. b.y) -. (a.y *. b.x);
  }

let[@inline] length_squared v = dot v v
let[@inline] length v = sqrt (length_squared v)
let[@inline] unit v = div v (length v)

(* Rejection sampling: pick points in the enclosing cube until one lands
   inside. *)
let rec random_in_unit_sphere st =
  let coord () = (2. *. Random.State.float st 1.) -. 1. in
  let x = coord () in
  let y = coord () in
  let z = coord () in
  let p = make x y z in
  if length_squared p < 1. then p else random_in_unit_sphere st

let rec random_in_unit_disk st =
  let coord () = (2. *. Random.State.float st 1.) -. 1. in
  let x = coord () in
  let y = coord () in
  let p = make x y 0. in
  if length_squared p < 1. then p else random_in_unit_disk st

(* Operators for use with a local open, e.g. [Vec3.(a + (2. * b))]. These
   shadow the integer operators, so they are defined last. *)
let ( + ) = add
let ( - ) = sub
let ( * ) = scale
let ( / ) = div
let ( ~- ) = neg
