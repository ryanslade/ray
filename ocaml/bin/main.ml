open Raytracer

let width = 800
let height = 450
let samples = 100

let random_world st =
  let rnd () = Random.State.float st 1. in
  let small_sphere a b =
    let x = a +. (0.9 *. rnd ()) in
    let z = b +. (0.9 *. rnd ()) in
    let center = Vec3.make x 0.2 z in
    if Vec3.(length (center - make 4. 0.2 0.)) <= 0.9 then None
    else
      (* Multiplication commutes, so the order the operands are drawn in
         doesn't matter. *)
      let channel () = rnd () *. rnd () in
      let r = channel () in
      let g = channel () in
      let b = channel () in
      Some (Sphere.make center 0.2 (Lambertian (Color.make r g b)))
  in
  let grid = List.init 22 (fun i -> float (i - 11)) in
  World.of_list
    (Sphere.make
       (Vec3.make 0. (-1000.) (-1.))
       1000.
       (Lambertian (Color.make 0.5 0.5 0.5))
     :: List.concat_map (fun a -> List.filter_map (small_sphere a) grid) grid
    @ [
        Sphere.make (Vec3.make 4. 1. 0.) 1.
          (Material.metal ~fuzz:0.1 (Color.make 0.8 0.6 0.2));
        Sphere.make (Vec3.make 0. 1. 0.) 1. (Dielectric 1.5);
        Sphere.make (Vec3.make (-4.) 1. 0.) 1.
          (Material.metal ~fuzz:0.2 (Color.make 0.8 0.8 0.8));
      ])

let () =
  let output = if Array.length Sys.argv > 1 then Sys.argv.(1) else "out.png" in
  prerr_endline "Generating world";
  let world = random_world (Random.State.make [| 1 |]) in
  let look_from = Vec3.make 3. 2. 3. and look_at = Vec3.make 0. 0. (-1.) in
  let camera =
    Camera.make ~look_from ~look_at ~v_up:(Vec3.make 0. 1. 0.) ~vfov:90.
      ~aspect:(float width /. float height)
      ~aperture:0.01
      ~focus_dist:Vec3.(length (look_from - look_at))
  in
  Printf.eprintf "Rendering on %d domains\n%!"
    (Domain.recommended_domain_count ());
  let img = Render.render ~width ~height ~samples camera world in
  Out_channel.with_open_bin output (fun oc ->
      output_string oc (Image.to_png img));
  Printf.eprintf "Wrote %s\n" output
