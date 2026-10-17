// Mirrors BenchmarkRender in the Go version: the test scene at 100x100 with
// 50 samples per pixel. Usage: bench [iterations]

import Foundation
import Raytracer
import TestScene

let args = CommandLine.arguments
guard let iterations = args.count > 1 ? Int(args[1]) : 20, iterations > 0 else {
    FileHandle.standardError.write(Data("Invalid count: \(args[1])\n".utf8))
    exit(EXIT_FAILURE)
}

let (width, height) = (100, 100)
let camera = testCamera(width: width, height: height)
let world = testWorld()
let renderer = try Renderer()
@MainActor func run() throws {
    _ = try renderer.render(width: width, height: height, samples: 50, camera: camera, world: world)
}

// The first render also warms up the pipeline.
try run()
let start = ContinuousClock.now
for _ in 0..<iterations {
    try run()
}
let ms = (ContinuousClock.now - start) / .milliseconds(1)
print(
    "\(iterations) iterations on \(renderer.device.name): "
        + String(format: "%.2f ms/op", ms / Double(iterations)))
