// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "raytracer",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "raytracer", targets: ["Example"]),
        .executable(name: "bench", targets: ["Bench"]),
    ],
    targets: [
        // The shader is compiled from source when a Renderer is created, so
        // building doesn't need Xcode's offline Metal compiler.
        .target(name: "Raytracer", resources: [.copy("Shaders.metal")]),
        .executableTarget(name: "Example", dependencies: ["Raytracer"]),
        .executableTarget(name: "Bench", dependencies: ["Raytracer", "TestScene"]),
        // The scene used by the tests and benchmark.
        .target(name: "TestScene", dependencies: ["Raytracer"]),
        .testTarget(
            name: "RaytracerTests", dependencies: ["Raytracer", "TestScene"],
            resources: [.copy("reference.ppm")]),
    ]
)
