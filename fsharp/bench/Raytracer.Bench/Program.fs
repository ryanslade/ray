/// Mirrors BenchmarkRender in the Go version: the test scene at 100x100 with
/// 50 samples per pixel. Usage: Raytracer.Bench [iterations] [threads]
module Raytracer.Bench.Program

open System
open System.Diagnostics
open Raytracer
open Raytracer.Tests

[<EntryPoint>]
let main args =
    let arg i fallback =
        args |> Array.tryItem i |> Option.map int |> Option.defaultValue fallback

    let iterations = arg 0 20
    let threads = arg 1 Environment.ProcessorCount
    let camera = Scene.camera 100 100

    let run () =
        Render.renderOn threads 100 100 50 camera Scene.world |> ignore

    // Warms up, so that the JIT has compiled the optimised code.
    run ()
    let stopwatch = Stopwatch.StartNew()

    for _ in 1..iterations do
        run ()

    printfn
        "%d iterations on %d threads: %.2f ms/op"
        iterations
        threads
        (stopwatch.Elapsed.TotalMilliseconds / float iterations)

    0
