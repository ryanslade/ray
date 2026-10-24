(** An 8-bit RGB image. *)

type t

val create : width:int -> height:int -> t
val width : t -> int
val height : t -> int

val set : t -> x:int -> y:int -> Color.t -> unit
(** Stores a colour, clamping each channel to [0, 1]. Row 0 is the top. Writes
    to distinct pixels may happen concurrently from different domains. *)

val get : t -> x:int -> y:int -> int * int * int

val to_ppm : t -> string
(** Binary (P6) PPM encoding. *)

val save_ppm : t -> string -> unit

val to_png : t -> string
(** PNG encoding. The pixel data is stored uncompressed, so the file is about
    the same size as the PPM. *)

val save_png : t -> string -> unit
