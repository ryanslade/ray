(* Prints the MD5 of the test scene rendered as a PPM. Pass a path to also
   write the image itself, e.g. to inspect a golden mismatch. *)

open Raytracer

let () =
  let width = 200 and height = 200 in
  let camera = Test_scene.camera ~width ~height in
  let img = Render.render ~width ~height ~samples:100 camera Test_scene.world in
  if Array.length Sys.argv > 1 then
    Out_channel.with_open_bin Sys.argv.(1) (fun oc ->
        output_string oc (Image.to_ppm img));
  print_endline (Digest.to_hex (Digest.string (Image.to_ppm img)))
