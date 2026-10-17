(* Mirrors BenchmarkRender in the Go version: the test scene at 100x100 with 50
   samples per pixel. Usage: bench.exe [iterations] [domains] *)

open Raytracer

let () =
  let arg i default =
    if Array.length Sys.argv > i then int_of_string Sys.argv.(i) else default
  in
  let iterations = arg 1 20 in
  let domains = arg 2 (Domain.recommended_domain_count ()) in
  let width = 100 and height = 100 in
  let camera = Test_scene.camera ~width ~height in
  let run () =
    ignore
      (Render.render ~domains ~width ~height ~samples:50 camera Test_scene.world)
  in
  run ();
  let start = Unix.gettimeofday () in
  for _ = 1 to iterations do
    run ()
  done;
  let elapsed = Unix.gettimeofday () -. start in
  Printf.printf "%d iterations on %d domains: %.2f ms/op\n" iterations domains
    (elapsed *. 1000. /. float iterations)
