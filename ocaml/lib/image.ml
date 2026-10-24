type t = { width : int; height : int; pixels : Bytes.t }

let create ~width ~height =
  { width; height; pixels = Bytes.make (width * height * 3) '\000' }

let width img = img.width
let height img = img.height
let offset img ~x ~y = ((y * img.width) + x) * 3

let to_byte v =
  Char.unsafe_chr (int_of_float (255.99 *. Float.max 0. (Float.min 1. v)))

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

let crc_table =
  Array.init 256 (fun n ->
      let c = ref n in
      for _ = 1 to 8 do
        c := if !c land 1 = 1 then 0xEDB88320 lxor (!c lsr 1) else !c lsr 1
      done;
      !c)

let crc32 s =
  let c = ref 0xFFFFFFFF in
  String.iter
    (fun ch -> c := crc_table.(!c lxor Char.code ch land 0xFF) lxor (!c lsr 8))
    s;
  !c lxor 0xFFFFFFFF

let adler32 s =
  let a = ref 1 and b = ref 0 in
  String.iter
    (fun ch ->
      a := (!a + Char.code ch) mod 65521;
      b := (!b + !a) mod 65521)
    s;
  (!b lsl 16) lor !a

let add_int32 buf n = Buffer.add_int32_be buf (Int32.of_int n)

(* A zlib stream holding [data] in uncompressed (stored) deflate blocks, which
   can be at most 65535 bytes each. The standard library has no compressor, and
   this keeps the encoder small at the cost of file size. *)
let zlib_stored data =
  let len = String.length data in
  let buf = Buffer.create (len + (len / 65535 * 5) + 16) in
  Buffer.add_string buf "\x78\x01";
  let rec blocks pos =
    let n = Int.min 65535 (len - pos) in
    let last = pos + n = len in
    Buffer.add_uint8 buf (if last then 1 else 0);
    Buffer.add_uint16_le buf n;
    Buffer.add_uint16_le buf (lnot n land 0xFFFF);
    Buffer.add_substring buf data pos n;
    if not last then blocks (pos + n)
  in
  blocks 0;
  add_int32 buf (adler32 data);
  Buffer.contents buf

let add_chunk buf kind data =
  add_int32 buf (String.length data);
  Buffer.add_string buf kind;
  Buffer.add_string buf data;
  add_int32 buf (crc32 (kind ^ data))

let to_png img =
  let header = Buffer.create 13 in
  add_int32 header img.width;
  add_int32 header img.height;
  (* 8 bits per channel, RGB, deflate, no filtering, no interlacing. *)
  Buffer.add_string header "\x08\x02\x00\x00\x00";
  (* Each scanline starts with its filter type, 0 for none. *)
  let row_bytes = img.width * 3 in
  let raw = Buffer.create ((row_bytes + 1) * img.height) in
  for y = 0 to img.height - 1 do
    Buffer.add_char raw '\000';
    Buffer.add_subbytes raw img.pixels (y * row_bytes) row_bytes
  done;
  let buf = Buffer.create (Buffer.length raw + 64) in
  Buffer.add_string buf "\x89PNG\r\n\x1a\n";
  add_chunk buf "IHDR" (Buffer.contents header);
  add_chunk buf "IDAT" (zlib_stored (Buffer.contents raw));
  add_chunk buf "IEND" "";
  Buffer.contents buf

let save_png img path =
  Out_channel.with_open_bin path (fun oc -> output_string oc (to_png img))
