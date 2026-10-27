(* An 8-bit RGB image. *)
type t = { width : int; height : int; pixels : Bytes.t }

let create ~width ~height =
  { width; height; pixels = Bytes.make (width * height * 3) '\000' }

let to_byte v =
  Char.unsafe_chr (int_of_float (255.99 *. Float.max 0. (Float.min 1. v)))

(* Stores a colour, clamping each channel to [0, 1]. Row 0 is the top. Writes to
   distinct pixels may happen concurrently from different domains. *)
let set img ~x ~y (c : Color.t) =
  let i = ((y * img.width) + x) * 3 in
  Bytes.set img.pixels i (to_byte c.r);
  Bytes.set img.pixels (i + 1) (to_byte c.g);
  Bytes.set img.pixels (i + 2) (to_byte c.b)

let get img ~x ~y =
  let channel j =
    Char.code (Bytes.get img.pixels ((((y * img.width) + x) * 3) + j))
  in
  (channel 0, channel 1, channel 2)

(* Binary (P6) PPM encoding. *)
let to_ppm img =
  Printf.sprintf "P6\n%d %d\n255\n%s" img.width img.height
    (Bytes.to_string img.pixels)

let crc32 s =
  let c = ref 0xFFFFFFFF in
  String.iter
    (fun ch ->
      c := !c lxor Char.code ch;
      for _ = 1 to 8 do
        c := if !c land 1 = 1 then 0xEDB88320 lxor (!c lsr 1) else !c lsr 1
      done)
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

let be32 n =
  String.init 4 (fun i -> Char.chr ((n lsr (24 - (8 * i))) land 0xFF))

(* A zlib stream holding [data] in uncompressed (stored) deflate blocks, which
   can be at most 65535 bytes each. The standard library has no compressor, and
   this keeps the encoder small at the cost of file size. *)
let zlib_stored data =
  let len = String.length data in
  let buf = Buffer.create len in
  Buffer.add_string buf "\x78\x01";
  let rec blocks pos =
    let n = Int.min 65535 (len - pos) in
    Buffer.add_uint8 buf (Bool.to_int (pos + n = len));
    Buffer.add_uint16_le buf n;
    Buffer.add_uint16_le buf (lnot n land 0xFFFF);
    Buffer.add_substring buf data pos n;
    if pos + n < len then blocks (pos + n)
  in
  blocks 0;
  Buffer.contents buf ^ be32 (adler32 data)

let chunk kind data =
  be32 (String.length data) ^ kind ^ data ^ be32 (crc32 (kind ^ data))

(* A PNG with the pixel data stored uncompressed, so the file is about the same
   size as the PPM. *)
let to_png img =
  let row = img.width * 3 in
  (* Each scanline starts with its filter type, 0 for none. *)
  let scanline y = "\000" ^ Bytes.sub_string img.pixels (y * row) row in
  String.concat ""
    [
      "\x89PNG\r\n\x1a\n";
      (* 8 bits per channel, RGB, deflate, no filtering, no interlacing. *)
      chunk "IHDR" (be32 img.width ^ be32 img.height ^ "\x08\x02\x00\x00\x00");
      chunk "IDAT"
        (zlib_stored (String.concat "" (List.init img.height scanline)));
      chunk "IEND" "";
    ]
