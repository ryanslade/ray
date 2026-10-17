open Raytracer

let float = Alcotest.float 1e-9

let vec3 =
  Alcotest.testable
    (fun ppf (v : Vec3.t) -> Format.fprintf ppf "(%g, %g, %g)" v.x v.y v.z)
    (fun (a : Vec3.t) b ->
      Float.abs (a.x -. b.x) < 1e-9
      && Float.abs (a.y -. b.y) < 1e-9
      && Float.abs (a.z -. b.z) < 1e-9)

let test_vec3 () =
  let a = Vec3.make 1. 2. 3. and b = Vec3.make 4. 5. 6. in
  Alcotest.check vec3 "add" (Vec3.make 5. 7. 9.) Vec3.(a + b);
  Alcotest.check vec3 "scale" (Vec3.make 2. 4. 6.) Vec3.(2. * a);
  Alcotest.check float "dot" 32. (Vec3.dot a b);
  Alcotest.check vec3 "cross" (Vec3.make (-3.) 6. (-3.)) (Vec3.cross a b);
  Alcotest.check float "unit length" 1. (Vec3.length (Vec3.unit b))

let test_sphere_hit () =
  let s = Sphere.make (Vec3.make 0. 0. (-1.)) 0.5 (Material.dielectric 1.5) in
  let towards = { Ray.origin = Vec3.zero; direction = Vec3.make 0. 0. (-1.) } in
  (match Sphere.hit s towards ~t_min:0. ~t_max:Float.infinity with
  | Some h ->
      Alcotest.check float "nearest t" 0.5 h.t;
      Alcotest.check vec3 "normal" (Vec3.make 0. 0. 1.) h.normal
  | None -> Alcotest.fail "expected a hit");
  (match Sphere.hit s towards ~t_min:0.6 ~t_max:Float.infinity with
  | Some h -> Alcotest.check float "far side" 1.5 h.t
  | None -> Alcotest.fail "expected a hit on the far side");
  let away = { towards with direction = Vec3.make 0. 1. 0. } in
  Alcotest.(check bool)
    "miss" true
    (Option.is_none (Sphere.hit s away ~t_min:0. ~t_max:Float.infinity))

let test_world_closest () =
  let m = Material.dielectric 1.5 in
  let world =
    World.of_list
      [
        Sphere.make (Vec3.make 0. 0. (-5.)) 1. m;
        Sphere.make (Vec3.make 0. 0. (-2.)) 0.5 m;
      ]
  in
  let ray = { Ray.origin = Vec3.zero; direction = Vec3.make 0. 0. (-1.) } in
  match World.hit world ray ~t_min:0. ~t_max:Float.infinity with
  | Some h -> Alcotest.check float "closest" 1.5 h.t
  | None -> Alcotest.fail "expected a hit"

let test_total_internal_reflection () =
  let n = Vec3.make 0. 1. 0. in
  let grazing = Vec3.make 1. (-0.1) 0. in
  Alcotest.(check bool)
    "no refraction" true
    (Option.is_none (Material.refract grazing n 1.5))

let test_deterministic_across_domains () =
  let width = 40 and height = 30 in
  let camera = Test_scene.camera ~width ~height in
  let render domains =
    Render.render ~domains ~width ~height ~samples:8 camera Test_scene.world
    |> Image.to_ppm
  in
  let expected = render 1 in
  List.iter
    (fun d ->
      Alcotest.(check bool)
        (Printf.sprintf "%d domains" d)
        true
        (String.equal expected (render d)))
    [ 2; 4; 7 ]

let () =
  Alcotest.run "raytracer"
    [
      ("vec3", [ Alcotest.test_case "arithmetic" `Quick test_vec3 ]);
      ( "geometry",
        [
          Alcotest.test_case "sphere hit" `Quick test_sphere_hit;
          Alcotest.test_case "world closest hit" `Quick test_world_closest;
          Alcotest.test_case "total internal reflection" `Quick
            test_total_internal_reflection;
        ] );
      ( "render",
        [
          Alcotest.test_case "deterministic across domains" `Quick
            test_deterministic_across_domains;
        ] );
    ]
