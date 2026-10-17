type t = { width : int; height : int; pixels : Bytes.t }

let create ~width ~height =
  { width; height; pixels = Bytes.make (width * height * 3) '\000' }

let width img = img.width
let height img = img.height
let offset img ~x ~y = ((y * img.width) + x) * 3
let to_byte v = Char.unsafe_chr (int_of_float (255.99 *. Float.min 1. v))

let set img ~x ~y (c : Color.t) =
  let i = offset img ~x ~y in
  Bytes.set img.pixels i (to_byte c.r);
  Bytes.set img.pixels (i + 1) (to_byte c.g);
  Bytes.set img.pixels (i + 2) (to_byte c.b)

let get img ~x ~y =
  let i = offset img ~x ~y in
  let channel j = Char.code (Bytes.get img.pixels (i + j)) in
  (channel 0, channel 1, channel 2)

let to_ppm img =
  Printf.sprintf "P6\n%d %d\n255\n" img.width img.height
  ^ Bytes.to_string img.pixels

let save_ppm img path =
  Out_channel.with_open_bin path (fun oc -> output_string oc (to_ppm img))
