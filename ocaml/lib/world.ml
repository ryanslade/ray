type t = Sphere.t array

let of_list = Array.of_list

(* Returns the closest hit, shrinking [t_max] as nearer objects are found. *)
let hit world ray ~t_min ~t_max =
  (* Only the hit record for the closest sphere is ever needed, so just track
     which one it is until the end. *)
  let closest = ref (-1) and closest_t = ref t_max in
  for i = 0 to Array.length world - 1 do
    let t = Sphere.intersect world.(i) ray ~t_min ~t_max:!closest_t in
    if not (Float.is_nan t) then (
      closest := i;
      closest_t := t)
  done;
  if !closest < 0 then None
  else Some (Sphere.hit_at world.(!closest) ray !closest_t)
