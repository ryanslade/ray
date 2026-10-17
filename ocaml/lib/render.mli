val ray_color : World.t -> Ray.t -> Random.State.t -> Color.t
(** The colour seen along a ray, following up to 50 bounces. *)

val render :
  ?domains:int ->
  width:int ->
  height:int ->
  samples:int ->
  Camera.t ->
  World.t ->
  Image.t
(** Renders the world with [samples] rays per pixel, in parallel across
    [domains] domains (default: [Domain.recommended_domain_count ()]).

    Each row uses its own random state seeded from the row index, so the image
    is identical regardless of the number of domains. *)
