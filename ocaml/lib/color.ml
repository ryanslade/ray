type t = { r : float; g : float; b : float }

let[@inline] make r g b = { r; g; b }
let black = make 0. 0. 0.
let white = make 1. 1. 1.
let[@inline] add a b = { r = a.r +. b.r; g = a.g +. b.g; b = a.b +. b.b }
let[@inline] mul a b = { r = a.r *. b.r; g = a.g *. b.g; b = a.b *. b.b }
let[@inline] scale s c = { r = s *. c.r; g = s *. c.g; b = s *. c.b }
let[@inline] div c s = { r = c.r /. s; g = c.g /. s; b = c.b /. s }

(* Operators for use with a local open, e.g. [Color.(a + (b * c))]. [*] is
   component-wise; use [scale] to multiply by a scalar. *)
let ( + ) = add
let ( * ) = mul
let ( / ) = div
