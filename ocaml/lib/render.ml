let sky_blue = Color.make 0.5 0.7 1.0

(* The colour seen along a ray, following up to 50 bounces. *)
let rec ray_color ?(depth = 0) world (ray : Ray.t) st =
  match World.hit world ray ~t_min:0.001 ~t_max:Float.max_float with
  | Some { point; normal; material; _ } when depth < 50 -> (
      match Material.scatter material ray ~point ~normal st with
      | Some (attenuation, scattered) ->
          Color.(
            attenuation * ray_color ~depth:(Int.succ depth) world scattered st)
      | None -> Color.black)
  | Some _ -> Color.black
  | None ->
      let t = 0.5 *. ((Vec3.unit ray.direction).y +. 1.) in
      Color.(scale (1. -. t) white + scale t sky_blue)

(* Renders the world with [samples] rays per pixel, in parallel across [domains]
   domains. Each row uses its own random state seeded from the row index, so the
   image is identical regardless of the number of domains. *)
let render ?(domains = Domain.recommended_domain_count ()) ~width ~height
    ~samples (camera : Camera.t) world =
  if domains < 1 then invalid_arg "Render.render: domains must be positive";
  let img = Image.create ~width ~height in
  let render_row y =
    let st = Random.State.make [| y + 1 |] in
    let rnd () = Random.State.float st 1. in
    for x = 0 to width - 1 do
      let c = ref Color.black in
      for _ = 1 to samples do
        let u = (float x +. rnd ()) /. float width in
        let v = (float (height - 1 - y) +. rnd ()) /. float height in
        c := Color.(!c + ray_color world (camera u v st) st)
      done;
      Image.set img ~x ~y Color.(!c / float samples)
    done
  in
  (* Rows vary a lot in cost (sky is cheap, spheres are expensive), so domains
     take rows one at a time rather than a fixed block each. *)
  let next_row = Atomic.make 0 in
  let rec worker () =
    let y = Atomic.fetch_and_add next_row 1 in
    if y < height then (
      render_row y;
      worker ())
  in
  let helpers = List.init (domains - 1) (fun _ -> Domain.spawn worker) in
  Fun.protect worker ~finally:(fun () -> List.iter Domain.join helpers);
  img
