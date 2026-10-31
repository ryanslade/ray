module Raytracer.Tests.Tests

open System
open System.Buffers.Binary
open System.IO
open System.IO.Compression
open System.Text
open Expecto
open Raytracer

let close a b = Vec3.length (a - b) < 1e-9

let floats n (rng: Rng) = List.init n (fun _ -> rng.NextFloat())

/// Splits a PNG into its chunks, as (type, data) pairs.
let rec pngChunks (bytes: byte array) =
    if bytes.Length = 0 then
        []
    else
        let length = BinaryPrimitives.ReadInt32BigEndian bytes

        (Encoding.ASCII.GetString(bytes, 4, 4), bytes[8 .. 7 + length])
        :: pngChunks bytes[12 + length ..]

let inflate (data: byte array) =
    use zlib = new ZLibStream(new MemoryStream(data), CompressionMode.Decompress)
    use raw = new MemoryStream()
    zlib.CopyTo raw
    raw.ToArray()

/// Renders the test scene and compares it with golden.ppm.
///
/// After an intentional change to the output, run with UPDATE_GOLDEN=1 to
/// accept it. On a mismatch the rendered image is written to
/// golden.actual.ppm for inspection.
let goldenImage () =
    let actual =
        Render.render 200 200 100 (Scene.camera 200 200) Scene.world |> Image.toPpm

    let golden = Path.Join(__SOURCE_DIRECTORY__, "golden.ppm")

    if isNull (Environment.GetEnvironmentVariable "UPDATE_GOLDEN") then
        if actual <> File.ReadAllBytes golden then
            let output = Path.Join(__SOURCE_DIRECTORY__, "golden.actual.ppm")
            File.WriteAllBytes(output, actual)
            failtestf "the rendered image doesn't match %s; wrote it to %s" golden output
    else
        File.WriteAllBytes(golden, actual)

[<Tests>]
let tests =
    testList
        "raytracer"
        [
            test "vector arithmetic" {
                let a = Vec3.make 1.0 2.0 3.0
                let b = Vec3.make 4.0 5.0 6.0
                Expect.isTrue (close (a + b) (Vec3.make 5.0 7.0 9.0)) "add"
                Expect.isTrue (close (2.0 * a) (Vec3.make 2.0 4.0 6.0)) "scale"
                Expect.equal (Vec3.dot a b) 32.0 "dot"
                Expect.isTrue (close (Vec3.cross a b) (Vec3.make -3.0 6.0 -3.0)) "cross"
                Expect.floatClose Accuracy.high (Vec3.length (Vec3.unit b)) 1.0 "unit"
            }

            test "random numbers are in [0, 1)" {
                Expect.all (floats 10_000 (Rng 1UL)) (fun f -> f >= 0.0 && f < 1.0) "in range"
            }

            test "the same seed gives the same sequence" {
                Expect.equal (floats 100 (Rng 42UL)) (floats 100 (Rng 42UL)) "sequences"
            }

            test "the generator matches SplitMix64" {
                // The first outputs for seed 0 from the reference implementation.
                let rng = Rng 0UL
                Expect.equal (rng.NextUInt64()) 0xe220a8397b1dcdafUL "first"
                Expect.equal (rng.NextUInt64()) 0x6e789e6aa1b965f4UL "second"
            }

            test "a ray hits a sphere" {
                let s = Sphere.create (Vec3.make 0.0 0.0 -1.0) 0.5 (Dielectric 1.5)

                let towards =
                    {
                        Origin = Vec3.zero
                        Direction = Vec3.make 0.0 0.0 -1.0
                    }

                match Sphere.hit s towards 0.0 infinity with
                | ValueSome hit ->
                    Expect.equal hit.T 0.5 "t"
                    Expect.equal hit.Normal (Vec3.make 0.0 0.0 1.0) "normal"
                | ValueNone -> failtest "expected a hit"

                let far = Sphere.hit s towards 0.6 infinity |> ValueOption.map _.T
                Expect.equal far (ValueSome 1.5) "far side"

                let away =
                    {
                        Origin = Vec3.zero
                        Direction = Vec3.make 0.0 1.0 0.0
                    }

                Expect.isTrue (Sphere.hit s away 0.0 infinity).IsNone "going away"
            }

            test "the world finds the closest hit" {
                let m = Dielectric 1.5

                let world =
                    World.ofSeq
                        [
                            Sphere.create (Vec3.make 0.0 0.0 -5.0) 1.0 m
                            Sphere.create (Vec3.make 0.0 0.0 -2.0) 0.5 m
                        ]

                let ray =
                    {
                        Origin = Vec3.zero
                        Direction = Vec3.make 0.0 0.0 -1.0
                    }

                let t = World.hit world ray 0.0 infinity |> ValueOption.map _.T
                Expect.equal t (ValueSome 1.5) "t"
            }

            test "total internal reflection" {
                let refracted =
                    Material.refract (Vec3.make 1.0 -0.1 0.0) (Vec3.make 0.0 1.0 0.0) 1.5

                Expect.isTrue refracted.IsNone "refracted"
            }

            test "refracts head on" {
                let down = Vec3.make 0.0 -1.0 0.0

                match Material.refract down (Vec3.make 0.0 1.0 0.0) (1.0 / 1.5) with
                | ValueSome r -> Expect.isTrue (close r down) "direction"
                | ValueNone -> failtest "should refract"
            }

            test "metal fuzz is clamped" {
                Expect.equal (Material.metal Color.white 2.0) (Metal(Color.white, 1.0)) "above"
                Expect.equal (Material.metal Color.white -1.0) (Metal(Color.white, 0.0)) "below"
            }

            test "setting a pixel clamps each channel" {
                let img = Image.create 2 1
                Image.set img 1 0 (Color.make 2.0 0.5 -1.0)
                Expect.equal (Image.get img 0 0) (0uy, 0uy, 0uy) "untouched"
                Expect.equal (Image.get img 1 0) (255uy, 127uy, 0uy) "clamped"

                Expect.throwsT<ArgumentOutOfRangeException>
                    (fun () -> Image.get img 2 0 |> ignore)
                    "bounds"
            }

            test "PPM header" {
                let ppm = Image.toPpm (Image.create 3 2)
                Expect.equal ppm[..10] "P6\n3 2\n255\n"B "header"
                Expect.equal ppm.Length (11 + 3 * 2 * 3) "length"
            }

            test "PNG" {
                let width, height = 20, 12
                let img = Image.create width height

                for y in 0 .. height - 1 do
                    for x in 0 .. width - 1 do
                        let c =
                            Color.make
                                (float x / float width)
                                (float y / float height)
                                (float ((x + y) % 7) / 7.0)

                        Image.set img x y c

                let png = Image.toPng img

                Expect.equal
                    png[..7]
                    [| 0x89uy; 'P'B; 'N'B; 'G'B; '\r'B; '\n'B; 0x1auy; '\n'B |]
                    "signature"
                // IEND's CRC is the same in every PNG, which checks the CRC code.
                Expect.equal
                    png[png.Length - 12 ..]
                    [| 0uy; 0uy; 0uy; 0uy; yield! "IEND"B; 0xaeuy; 0x42uy; 0x60uy; 0x82uy |]
                    "IEND"

                match pngChunks png[8..] with
                | [ ("IHDR", header); ("IDAT", data); ("IEND", [||]) ] ->
                    Expect.equal (BinaryPrimitives.ReadInt32BigEndian header) width "width"

                    Expect.equal
                        (BinaryPrimitives.ReadInt32BigEndian(ReadOnlySpan(header, 4, 4)))
                        height
                        "height"

                    Expect.equal header[8..] [| 8uy; 2uy; 0uy; 0uy; 0uy |] "8-bit RGB"
                    let rows = inflate data |> Array.chunkBySize (1 + 3 * width)
                    Expect.equal rows.Length height "rows"

                    for y, row in Array.indexed rows do
                        Expect.equal row[0] 0uy "no filter"

                        for x in 0 .. width - 1 do
                            let pixel = row[1 + 3 * x], row[2 + 3 * x], row[3 + 3 * x]
                            Expect.equal pixel (Image.get img x y) $"pixel ({x}, {y})"
                | chunks -> failtestf "unexpected chunks %A" (List.map fst chunks)
            }

            test "the image is the same whatever the number of threads" {
                let camera = Scene.camera 40 30

                let render threads =
                    Render.renderOn threads 40 30 8 camera Scene.world |> Image.toPpm

                let expected = render 1

                for threads in [ 2; 4; 7 ] do
                    Expect.equal (render threads) expected $"{threads} threads"
            }

            test "golden image" { goldenImage () }
        ]

[<EntryPoint>]
let main args = runTestsInAssemblyWithCLIArgs [] args
