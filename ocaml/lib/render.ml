let max_depth = 50
let sky_blue = Color.make 0.5 0.7 1.0

let ray_color world ray st =
  let rec go (ray : Ray.t) depth =
    match World.hit world ray ~t_min:0.001 ~t_max:Float.max_float with
    | Some { point; normal; material; _ } -> (
        if depth >= max_depth then Color.black
        else
          match Material.scatter material ray ~point ~normal st with
          | Some (attenuation, scattered) ->
              Color.(attenuation * go scattered (Int.succ depth))
          | None -> Color.black)
    | None ->
        let t = 0.5 *. ((Vec3.unit ray.direction).y +. 1.) in
        Color.(scale (1. -. t) white + scale t sky_blue)
  in
  go ray 0

let render_row img ~samples camera world y =
  let width = Image.width img and height = Image.height img in
  let st = Random.State.make [| y + 1 |] in
  for x = 0 to width - 1 do
    let c = ref Color.black in
    for _ = 1 to samples do
      let u = (float x +. Random.State.float st 1.) /. float width in
      let v =
        (float (height - 1 - y) +. Random.State.float st 1.) /. float height
      in
      let ray = Camera.get_ray camera u v st in
      c := Color.(!c + ray_color world ray st)
    done;
    Image.set img ~x ~y Color.(!c / float samples)
  done

let render ?(domains = Domain.recommended_domain_count ()) ~width ~height
    ~samples camera world =
  if domains < 1 then invalid_arg "Render.render: domains must be positive";
  let img = Image.create ~width ~height in
  (* Rows vary a lot in cost (sky is cheap, spheres are expensive), so domains
     take rows one at a time rather than a fixed block each. *)
  let next_row = Atomic.make 0 in
  let rec worker () =
    let y = Atomic.fetch_and_add next_row 1 in
    if y < height then (
      render_row img ~samples camera world y;
      worker ())
  in
  let helpers = List.init (domains - 1) (fun _ -> Domain.spawn worker) in
  Fun.protect worker ~finally:(fun () -> List.iter Domain.join helpers);
  img
