type t = Sphere.t array

let of_list = Array.of_list

(* Returns the closest hit, shrinking [t_max] as nearer objects are found. *)
let hit world ray ~t_min ~t_max =
  let closest = ref None in
  for i = 0 to Array.length world - 1 do
    let t_max = match !closest with Some (h : Hit.t) -> h.t | None -> t_max in
    match Sphere.hit world.(i) ray ~t_min ~t_max with
    | Some _ as h -> closest := h
    | None -> ()
  done;
  !closest
