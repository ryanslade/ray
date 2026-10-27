open Raytracer

let float = Alcotest.float 1e-9

let vec3 =
  Alcotest.testable
    (fun ppf (v : Vec3.t) -> Format.fprintf ppf "(%g, %g, %g)" v.x v.y v.z)
    (fun (a : Vec3.t) b ->
      Float.abs (a.x -. b.x) < 1e-9
      && Float.abs (a.y -. b.y) < 1e-9
      && Float.abs (a.z -. b.z) < 1e-9)

let color =
  Alcotest.testable
    (fun ppf (c : Color.t) -> Format.fprintf ppf "(%g, %g, %g)" c.r c.g c.b)
    (fun (a : Color.t) b ->
      Float.abs (a.r -. b.r) < 1e-9
      && Float.abs (a.g -. b.g) < 1e-9
      && Float.abs (a.b -. b.b) < 1e-9)

let rgb = Alcotest.(triple int int int)
let glass = Material.Dielectric 1.5

let test_vec3 () =
  let a = Vec3.make 1. 2. 3. and b = Vec3.make 4. 5. 6. in
  Alcotest.check vec3 "add" (Vec3.make 5. 7. 9.) Vec3.(a + b);
  Alcotest.check vec3 "scale" (Vec3.make 2. 4. 6.) Vec3.(2. * a);
  Alcotest.check float "dot" 32. (Vec3.dot a b);
  Alcotest.check vec3 "cross" (Vec3.make (-3.) 6. (-3.)) (Vec3.cross a b);
  Alcotest.check float "unit length" 1. (Vec3.length (Vec3.unit b))

let test_random_in_unit_sphere () =
  let st = Random.State.make [| 1 |] in
  for _ = 1 to 1000 do
    let p = Vec3.random_in_unit_sphere st in
    if Vec3.length_squared p >= 1. then
      Alcotest.failf "(%g, %g, %g) is outside the unit sphere" p.x p.y p.z
  done

let test_random_in_unit_disk () =
  let st = Random.State.make [| 1 |] in
  for _ = 1 to 1000 do
    let p = Vec3.random_in_unit_disk st in
    if Vec3.length_squared p >= 1. || p.z <> 0. then
      Alcotest.failf "(%g, %g, %g) is outside the unit disk" p.x p.y p.z
  done

let test_sphere_hit () =
  let s = Sphere.make (Vec3.make 0. 0. (-1.)) 0.5 glass in
  let towards = { Ray.origin = Vec3.zero; direction = Vec3.make 0. 0. (-1.) } in
  (match Sphere.hit s towards ~t_min:0. ~t_max:Float.infinity with
  | Some h ->
      Alcotest.check float "nearest t" 0.5 h.t;
      Alcotest.check vec3 "normal" (Vec3.make 0. 0. 1.) h.normal
  | None -> Alcotest.fail "expected a hit");
  (match Sphere.hit s towards ~t_min:0.6 ~t_max:Float.infinity with
  | Some h -> Alcotest.check float "far side" 1.5 h.t
  | None -> Alcotest.fail "expected a hit on the far side");
  Alcotest.(check bool)
    "short t_max" true
    (Option.is_none (Sphere.hit s towards ~t_min:0. ~t_max:0.4));
  let away = { towards with direction = Vec3.make 0. 1. 0. } in
  Alcotest.(check bool)
    "miss" true
    (Option.is_none (Sphere.hit s away ~t_min:0. ~t_max:Float.infinity))

let test_sphere_hit_unnormalised () =
  let s = Sphere.make (Vec3.make 0. 0. (-1.)) 0.5 glass in
  let ray = { Ray.origin = Vec3.zero; direction = Vec3.make 0. 0. (-2.) } in
  match Sphere.hit s ray ~t_min:0. ~t_max:Float.infinity with
  | Some h ->
      Alcotest.check float "t" 0.25 h.t;
      Alcotest.check vec3 "point" (Vec3.make 0. 0. (-0.5)) h.point
  | None -> Alcotest.fail "expected a hit"

let test_sphere_hit_from_inside () =
  let s = Sphere.make (Vec3.make 0. 0. (-1.)) 0.5 glass in
  let ray =
    { Ray.origin = Vec3.make 0. 0. (-1.); direction = Vec3.make 0. 0. (-1.) }
  in
  match Sphere.hit s ray ~t_min:0. ~t_max:Float.infinity with
  | Some h ->
      Alcotest.check float "t" 0.5 h.t;
      Alcotest.check vec3 "outward normal" (Vec3.make 0. 0. (-1.)) h.normal
  | None -> Alcotest.fail "expected a hit"

let test_world_closest () =
  let spheres =
    [
      Sphere.make (Vec3.make 0. 0. (-5.)) 1. glass;
      Sphere.make (Vec3.make 0. 0. (-2.)) 0.5 glass;
    ]
  in
  let ray = { Ray.origin = Vec3.zero; direction = Vec3.make 0. 0. (-1.) } in
  List.iter
    (fun (name, spheres) ->
      match
        World.hit (World.of_list spheres) ray ~t_min:0. ~t_max:Float.infinity
      with
      | Some h -> Alcotest.check float name 1.5 h.t
      | None -> Alcotest.fail "expected a hit")
    [ ("closest", spheres); ("closest, reversed", List.rev spheres) ]

let test_world_misses () =
  let ray = { Ray.origin = Vec3.zero; direction = Vec3.make 0. 0. (-1.) } in
  Alcotest.(check bool)
    "empty world" true
    (Option.is_none
       (World.hit (World.of_list []) ray ~t_min:0. ~t_max:Float.infinity));
  let world = World.of_list [ Sphere.make (Vec3.make 0. 0. (-5.)) 1. glass ] in
  Alcotest.(check bool)
    "beyond t_max" true
    (Option.is_none (World.hit world ray ~t_min:0. ~t_max:3.))

(* [World.hit] tracks only the index of the closest sphere, so check it finds
   exactly the hit that trying [Sphere.hit] on each sphere in turn would, for
   worlds of every size up to the number of spheres. *)
let test_world_matches_sphere_by_sphere () =
  let st = Random.State.make [| 1 |] in
  let coord scale = scale *. ((2. *. Random.State.float st 1.) -. 1.) in
  let spheres =
    List.init 23 (fun _ ->
        let center = Vec3.make (coord 3.) (coord 3.) (coord 3.) in
        Sphere.make center (0.1 +. Float.abs (coord 1.)) glass)
  in
  let rays =
    List.init 2000 (fun _ ->
        {
          Ray.origin = Vec3.make (coord 5.) (coord 5.) (coord 5.);
          direction = Vec3.make (coord 1.) (coord 1.) (coord 1.);
        })
  in
  let summary = Option.map (fun (h : Hit.t) -> (h.t, h.point, h.normal)) in
  let hit = Alcotest.option (Alcotest.triple float vec3 vec3) in
  for n = 0 to List.length spheres do
    let spheres = List.filteri (fun i _ -> i < n) spheres in
    let world = World.of_list spheres in
    List.iter
      (fun ray ->
        let want =
          List.fold_left
            (fun (closest : Hit.t option) s ->
              let t_max =
                Option.fold ~none:Float.max_float
                  ~some:(fun (h : Hit.t) -> h.t)
                  closest
              in
              match Sphere.hit s ray ~t_min:0.001 ~t_max with
              | Some _ as h -> h
              | None -> closest)
            None spheres
        in
        Alcotest.check hit
          (Printf.sprintf "%d spheres" n)
          (summary want)
          (summary (World.hit world ray ~t_min:0.001 ~t_max:Float.max_float)))
      rays
  done

let test_reflect () =
  Alcotest.check vec3 "mirror" (Vec3.make 1. 1. 0.)
    (Material.reflect (Vec3.make 1. (-1.) 0.) (Vec3.make 0. 1. 0.))

let test_total_internal_reflection () =
  let n = Vec3.make 0. 1. 0. in
  let grazing = Vec3.make 1. (-0.1) 0. in
  Alcotest.(check bool)
    "no refraction" true
    (Option.is_none (Material.refract grazing n 1.5))

let test_refracts_head_on () =
  let n = Vec3.make 0. 1. 0. in
  let down = Vec3.make 0. (-1.) 0. in
  match Material.refract down n (1. /. 1.5) with
  | Some r -> Alcotest.check vec3 "straight through" down r
  | None -> Alcotest.fail "expected refraction"

let test_schlick () =
  Alcotest.check float "head on" 0.04 (Material.schlick 1. 1.5);
  Alcotest.check float "grazing" 1. (Material.schlick 0. 1.5)

let test_metal_fuzz_is_clamped () =
  List.iter
    (fun (given, want) ->
      match Material.metal ~fuzz:given Color.white with
      | Metal (_, fuzz) ->
          Alcotest.check float (Printf.sprintf "fuzz %g" given) want fuzz
      | Lambertian _ | Dielectric _ -> Alcotest.fail "expected metal")
    [ (2., 1.); (-1., 0.); (0.3, 0.3) ]

let test_metal_scatter () =
  let st = Random.State.make [| 1 |] in
  let albedo = Color.make 0.8 0.6 0.2 in
  let mirror = Material.metal albedo in
  let point = Vec3.make 1. 2. 3. and normal = Vec3.make 0. 1. 0. in
  let ray_in direction = { Ray.origin = Vec3.zero; direction } in
  (match
     Material.scatter mirror (ray_in (Vec3.make 1. (-1.) 0.)) ~point ~normal st
   with
  | Some (attenuation, scattered) ->
      Alcotest.check color "attenuation" albedo attenuation;
      Alcotest.check vec3 "origin" point scattered.origin;
      Alcotest.check vec3 "mirror reflection"
        (Vec3.unit (Vec3.make 1. 1. 0.))
        scattered.direction
  | None -> Alcotest.fail "expected a reflection");
  Alcotest.(check bool)
    "absorbed below the surface" true
    (Option.is_none
       (Material.scatter mirror (ray_in (Vec3.make 1. 1. 0.)) ~point ~normal st))

let test_lambertian_scatter () =
  let st = Random.State.make [| 1 |] in
  let albedo = Color.make 0.8 0.6 0.2 in
  let point = Vec3.make 1. 2. 3. and normal = Vec3.make 0. 1. 0. in
  let ray_in = { Ray.origin = Vec3.zero; direction = Vec3.make 1. (-1.) 0. } in
  for _ = 1 to 1000 do
    match
      Material.scatter (Material.Lambertian albedo) ray_in ~point ~normal st
    with
    | Some (attenuation, scattered) ->
        Alcotest.check color "attenuation" albedo attenuation;
        if Vec3.dot scattered.direction normal <= 0. then
          Alcotest.fail "scattered into the surface"
    | None -> Alcotest.fail "expected a scatter"
  done

let test_dielectric_scatter () =
  let st = Random.State.make [| 1 |] in
  let point = Vec3.zero and normal = Vec3.make 0. 1. 0. in
  List.iter
    (fun (name, direction) ->
      let ray_in = { Ray.origin = Vec3.make 0. 1. 0.; direction } in
      for _ = 1 to 100 do
        match Material.scatter glass ray_in ~point ~normal st with
        | Some (attenuation, _) ->
            Alcotest.check color name Color.white attenuation
        | None -> Alcotest.fail "expected a scatter"
      done)
    [ ("entering", Vec3.make 1. (-1.) 0.); ("leaving", Vec3.make 1. 1. 0.) ]

let test_image_set_clamps () =
  let img = Image.create ~width:2 ~height:1 in
  Image.set img ~x:1 ~y:0 (Color.make 2. 0.5 (-1.));
  Alcotest.check rgb "untouched" (0, 0, 0) (Image.get img ~x:0 ~y:0);
  Alcotest.check rgb "clamped" (255, 127, 0) (Image.get img ~x:1 ~y:0)

let test_ppm_header () =
  let ppm = Image.to_ppm (Image.create ~width:3 ~height:2) in
  Alcotest.(check bool)
    "header" true
    (String.starts_with ~prefix:"P6\n3 2\n255\n" ppm);
  Alcotest.(check int) "length" (11 + (3 * 2 * 3)) (String.length ppm)

(* Splits a PNG into its chunks, as (type, data) pairs. *)
let png_chunks png =
  let int32 pos = Int32.to_int (String.get_int32_be png pos) land 0xFFFFFFFF in
  let rec go pos =
    if pos >= String.length png then []
    else
      let len = int32 pos in
      (String.sub png (pos + 4) 4, String.sub png (pos + 8) len)
      :: go (pos + 12 + len)
  in
  go 8

(* Decodes a zlib stream made of stored deflate blocks, the only kind
   [Image.to_png] writes. *)
let inflate_stored z =
  let buf = Buffer.create (String.length z) in
  let rec go pos =
    let header = Char.code z.[pos] in
    if (header lsr 1) land 3 <> 0 then Alcotest.fail "expected a stored block";
    let len = String.get_uint16_le z (pos + 1) in
    Alcotest.(check int)
      "NLEN"
      (lnot len land 0xFFFF)
      (String.get_uint16_le z (pos + 3));
    Buffer.add_string buf (String.sub z (pos + 5) len);
    if header land 1 = 0 then go (pos + 5 + len)
  in
  go 2;
  Buffer.contents buf

let test_png () =
  (* Big enough for the pixel data to need more than one stored block. *)
  let width = 200 and height = 120 in
  let img = Image.create ~width ~height in
  for y = 0 to height - 1 do
    for x = 0 to width - 1 do
      Image.set img ~x ~y
        (Color.make
           (Float.of_int x /. Float.of_int width)
           (Float.of_int y /. Float.of_int height)
           (Float.of_int ((x + y) mod 7) /. 7.))
    done
  done;
  let png = Image.to_png img in
  Alcotest.(check string) "signature" "\x89PNG\r\n\x1a\n" (String.sub png 0 8);
  match png_chunks png with
  | [ ("IHDR", header); ("IDAT", data); ("IEND", "") ] ->
      Alcotest.(check int)
        "width" width
        (Int32.to_int (String.get_int32_be header 0));
      Alcotest.(check int)
        "height" height
        (Int32.to_int (String.get_int32_be header 4));
      Alcotest.(check string)
        "8-bit RGB" "\x08\x02\x00\x00\x00" (String.sub header 8 5);
      (* IEND's CRC is the same in every PNG, which checks the CRC code. *)
      Alcotest.(check string)
        "IEND" "\x00\x00\x00\x00IEND\xae\x42\x60\x82"
        (String.sub png (String.length png - 12) 12);
      let raw = inflate_stored data in
      let row_bytes = 1 + (width * 3) in
      Alcotest.(check int)
        "data length" (row_bytes * height) (String.length raw);
      for y = 0 to height - 1 do
        Alcotest.(check char) "no filter" '\000' raw.[y * row_bytes];
        for x = 0 to width - 1 do
          let channel j = Char.code raw.[(y * row_bytes) + 1 + (x * 3) + j] in
          Alcotest.check rgb
            (Printf.sprintf "pixel (%d, %d)" x y)
            (Image.get img ~x ~y)
            (channel 0, channel 1, channel 2)
        done
      done
  | chunks ->
      Alcotest.failf "unexpected chunks: %s"
        (String.concat ", " (List.map fst chunks))

let test_camera () =
  let look_from = Vec3.make 1. 1. 1. and look_at = Vec3.make 0. 0. (-1.) in
  let camera =
    Camera.make ~look_from ~look_at ~v_up:(Vec3.make 0. 1. 0.) ~vfov:60.
      ~aspect:2. ~aperture:0. ~focus_dist:3.
  in
  let st = Random.State.make [| 1 |] in
  let centre = camera 0.5 0.5 st in
  Alcotest.check vec3 "origin" look_from centre.origin;
  Alcotest.check vec3 "towards look_at"
    Vec3.(unit (look_at - look_from))
    (Vec3.unit centre.direction);
  let top = camera 0.5 1. st in
  let angle =
    Float.acos (Vec3.dot (Vec3.unit centre.direction) (Vec3.unit top.direction))
  in
  Alcotest.check float "half the vertical fov" 30. (angle *. 180. /. Float.pi)

let test_sky () =
  let st = Random.State.make [| 1 |] in
  let empty = World.of_list [] in
  let sky direction =
    Render.ray_color empty { Ray.origin = Vec3.zero; direction } st
  in
  Alcotest.check color "up" (Color.make 0.5 0.7 1.) (sky (Vec3.make 0. 1. 0.));
  Alcotest.check color "down" Color.white (sky (Vec3.make 0. (-1.) 0.))

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

let test_more_domains_than_rows () =
  let width = 4 and height = 2 in
  let camera = Test_scene.camera ~width ~height in
  let render domains =
    Render.render ~domains ~width ~height ~samples:4 camera Test_scene.world
    |> Image.to_ppm
  in
  Alcotest.(check bool) "same image" true (String.equal (render 1) (render 5))

let test_single_pixel () =
  let camera = Test_scene.camera ~width:1 ~height:1 in
  let img =
    Render.render ~domains:1 ~width:1 ~height:1 ~samples:4 camera
      Test_scene.world
  in
  Alcotest.(check (pair int int)) "size" (1, 1) (img.width, img.height)

let test_rejects_no_domains () =
  let camera = Test_scene.camera ~width:4 ~height:2 in
  Alcotest.check_raises "zero domains"
    (Invalid_argument "Render.render: domains must be positive") (fun () ->
      ignore
        (Render.render ~domains:0 ~width:4 ~height:2 ~samples:1 camera
           Test_scene.world))

let () =
  Alcotest.run "raytracer"
    [
      ( "vec3",
        [
          Alcotest.test_case "arithmetic" `Quick test_vec3;
          Alcotest.test_case "random in unit sphere" `Quick
            test_random_in_unit_sphere;
          Alcotest.test_case "random in unit disk" `Quick
            test_random_in_unit_disk;
        ] );
      ( "geometry",
        [
          Alcotest.test_case "sphere hit" `Quick test_sphere_hit;
          Alcotest.test_case "sphere hit, unnormalised direction" `Quick
            test_sphere_hit_unnormalised;
          Alcotest.test_case "sphere hit from inside" `Quick
            test_sphere_hit_from_inside;
          Alcotest.test_case "world closest hit" `Quick test_world_closest;
          Alcotest.test_case "world misses" `Quick test_world_misses;
          Alcotest.test_case "world matches sphere by sphere" `Quick
            test_world_matches_sphere_by_sphere;
        ] );
      ( "material",
        [
          Alcotest.test_case "reflect" `Quick test_reflect;
          Alcotest.test_case "total internal reflection" `Quick
            test_total_internal_reflection;
          Alcotest.test_case "refracts head on" `Quick test_refracts_head_on;
          Alcotest.test_case "schlick" `Quick test_schlick;
          Alcotest.test_case "metal fuzz is clamped" `Quick
            test_metal_fuzz_is_clamped;
          Alcotest.test_case "metal scatter" `Quick test_metal_scatter;
          Alcotest.test_case "lambertian scatter" `Quick test_lambertian_scatter;
          Alcotest.test_case "dielectric scatter" `Quick test_dielectric_scatter;
        ] );
      ( "image",
        [
          Alcotest.test_case "set clamps" `Quick test_image_set_clamps;
          Alcotest.test_case "PPM header" `Quick test_ppm_header;
          Alcotest.test_case "PNG" `Quick test_png;
        ] );
      ("camera", [ Alcotest.test_case "rays" `Quick test_camera ]);
      ( "render",
        [
          Alcotest.test_case "sky" `Quick test_sky;
          Alcotest.test_case "deterministic across domains" `Quick
            test_deterministic_across_domains;
          Alcotest.test_case "more domains than rows" `Quick
            test_more_domains_than_rows;
          Alcotest.test_case "single pixel" `Quick test_single_pixel;
          Alcotest.test_case "rejects zero domains" `Quick
            test_rejects_no_domains;
        ] );
    ]
