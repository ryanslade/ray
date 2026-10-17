// Tests of the shader's functions, through kernels compiled along with it.
// Each kernel takes its inputs first and then its outputs.

import Metal
import Testing

@testable import Raytracer

private let testKernels = """

    kernel void test_layout(device uint *out [[buffer(0)]]) {
        out[0] = sizeof(Material);
        out[1] = __builtin_offsetof(Material, param);
        out[2] = __builtin_offsetof(Material, kind);
        out[3] = sizeof(Camera);
        out[4] = __builtin_offsetof(Camera, lower_left);
        out[5] = __builtin_offsetof(Camera, horizontal);
        out[6] = __builtin_offsetof(Camera, vertical);
        out[7] = __builtin_offsetof(Camera, u);
        out[8] = __builtin_offsetof(Camera, v);
        out[9] = __builtin_offsetof(Camera, lens_radius);
        out[10] = sizeof(Params);
        out[11] = sizeof(Sphere);
    }

    // The first `n` numbers from seed 42, as integers and as floats.
    kernel void test_rng(constant uint &n [[buffer(0)]], device ulong *ints [[buffer(1)]],
                         device float *floats [[buffer(2)]]) {
        ulong a = 42, b = 42;
        for (uint i = 0; i < n; i++) {
            ints[i] = next_u64(a);
            floats[i] = next_float(b);
        }
    }

    // For each ray (an origin and a direction), the distance to the closest
    // hit and the index of the sphere, or -1 for a miss.
    kernel void test_world_hit(constant Sphere *spheres [[buffer(0)]],
                               constant uint &count [[buffer(1)]],
                               constant float4 *rays [[buffer(2)]],
                               constant float &t_min [[buffer(3)]],
                               device float2 *out [[buffer(4)]],
                               uint i [[thread_position_in_grid]]) {
        Ray r = Ray{rays[2 * i].xyz, rays[2 * i + 1].xyz};
        uint index;
        float t;
        bool hit = world_hit(spheres, count, r, t_min, FLT_MAX, index, t);
        out[i] = hit ? float2(t, float(index)) : float2(-1);
    }

    // For each pair of v and n (with ni_over_nt in n.w), the refracted ray,
    // with a w of 0 on total internal reflection.
    kernel void test_refract(constant float4 *in [[buffer(0)]], device float4 *out [[buffer(1)]],
                             uint i [[thread_position_in_grid]]) {
        float3 r = float3(0);
        bool ok = try_refract(in[2 * i].xyz, in[2 * i + 1].xyz, in[2 * i + 1].w, r);
        out[i] = float4(r, ok ? 1 : 0);
    }
    """

private struct TestGPU {
    let device: MTLDevice
    let library: MTLLibrary

    init() throws {
        device = try #require(MTLCreateSystemDefaultDevice())
        library = try device.makeLibrary(
            source: Renderer.shaderSource() + testKernels, options: Renderer.compileOptions())
    }

    /// Runs a kernel on `threads` threads. Each input is copied into a buffer
    /// of its own, followed by an output buffer of each of `outputs` bytes,
    /// which are returned.
    func run(_ name: String, threads: Int = 1, inputs: [[UInt8]], outputs: [Int]) throws
        -> [UnsafeRawBufferPointer]
    {
        let function = try #require(library.makeFunction(name: name))
        let pipeline = try device.makeComputePipelineState(function: function)
        let queue = try #require(device.makeCommandQueue())
        let commands = try #require(queue.makeCommandBuffer())
        let encoder = try #require(commands.makeComputeCommandEncoder())
        encoder.setComputePipelineState(pipeline)
        let inBuffers = try inputs.map { bytes in
            try #require(
                device.makeBuffer(bytes: bytes, length: bytes.count, options: .storageModeShared))
        }
        let outBuffers = try outputs.map { length in
            try #require(device.makeBuffer(length: length, options: .storageModeShared))
        }
        for (i, buffer) in (inBuffers + outBuffers).enumerated() {
            encoder.setBuffer(buffer, offset: 0, index: i)
        }
        encoder.dispatchThreads(
            MTLSize(width: threads, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
        encoder.endEncoding()
        commands.commit()
        commands.waitUntilCompleted()
        #expect(commands.status == .completed)
        return outBuffers.map { UnsafeRawBufferPointer(start: $0.contents(), count: $0.length) }
    }
}

private func bytes<T>(_ values: [T]) -> [UInt8] {
    values.withUnsafeBytes { Array($0) }
}

private func values<T>(_ buffer: UnsafeRawBufferPointer, as type: T.Type) -> [T] {
    Array(buffer.bindMemory(to: T.self))
}

@Test func structLayoutsMatchShader() throws {
    let out = try TestGPU().run("test_layout", inputs: [], outputs: [12 * 4])
    let expected = [
        MemoryLayout<GPUMaterial>.stride,
        MemoryLayout<GPUMaterial>.offset(of: \.param)!,
        MemoryLayout<GPUMaterial>.offset(of: \.kind)!,
        MemoryLayout<GPUCamera>.stride,
        MemoryLayout<GPUCamera>.offset(of: \.lowerLeft)!,
        MemoryLayout<GPUCamera>.offset(of: \.horizontal)!,
        MemoryLayout<GPUCamera>.offset(of: \.vertical)!,
        MemoryLayout<GPUCamera>.offset(of: \.u)!,
        MemoryLayout<GPUCamera>.offset(of: \.v)!,
        MemoryLayout<GPUCamera>.offset(of: \.lensRadius)!,
        MemoryLayout<GPUParams>.stride,
        MemoryLayout<SIMD4<Float>>.stride,
    ]
    #expect(values(out[0], as: UInt32.self).map(Int.init) == expected)
}

@Test func shaderRngMatchesHost() throws {
    let n = 10000
    let out = try TestGPU().run(
        "test_rng", inputs: [bytes([UInt32(n)])], outputs: [n * 8, n * 4])
    let ints = values(out[0], as: UInt64.self)
    var rng = Rng(seed: 42)
    #expect(ints == (0..<n).map { _ in rng.nextU64() })
    // Floats are the top 24 bits of the same numbers, scaled to [0, 1).
    let floats = values(out[1], as: Float.self)
    #expect(floats == ints.map { Float($0 >> 40) / Float(1 << 24) })
    #expect(floats.allSatisfy { $0 >= 0 && $0 < 1 })
}

/// The closest hit for each ray, as a distance and a sphere index.
private func worldHit(_ world: [Sphere], rays: [(Vec3, Vec3)], tMin: Float = 0) throws -> [(
    Float, Int
)?] {
    let rayData = rays.flatMap { origin, direction -> [SIMD4<Float>] in
        [SIMD4(SIMD3<Float>(origin), 0), SIMD4(SIMD3<Float>(direction), 0)]
    }
    let out = try TestGPU().run(
        "test_world_hit", threads: rays.count,
        inputs: [
            bytes(world.map(gpuSphere)), bytes([UInt32(world.count)]), bytes(rayData),
            bytes([tMin]),
        ],
        outputs: [rays.count * 8])
    return values(out[0], as: SIMD2<Float>.self).map { $0.x < 0 ? nil : ($0.x, Int($0.y)) }
}

@Test func sphereHit() throws {
    let s = Sphere(center: Vec3(0, 0, -1), radius: 0.5, material: .dielectric(refIndex: 1.5))
    let towards = (Vec3(0, 0, 0), Vec3(0, 0, -1))
    let away = (Vec3(0, 0, 0), Vec3(0, 1, 0))
    let hits = try worldHit([s], rays: [towards, away])
    #expect(hits[0]?.0 == 0.5)
    #expect(hits[1] == nil)
    // Past the near side, the ray meets the far one.
    #expect(try worldHit([s], rays: [towards], tMin: 0.6)[0]?.0 == 1.5)
}

@Test func worldClosestHit() throws {
    let m = Material.dielectric(refIndex: 1.5)
    let world = [
        Sphere(center: Vec3(0, 0, -5), radius: 1, material: m),
        Sphere(center: Vec3(0, 0, -2), radius: 0.5, material: m),
    ]
    let hit = try worldHit(world, rays: [(Vec3(0, 0, 0), Vec3(0, 0, -1))])[0]
    #expect(hit?.0 == 1.5)
    #expect(hit?.1 == 1)
}

@Test func refraction() throws {
    let input: [SIMD4<Float>] = [
        // Total internal reflection.
        SIMD4(1, -0.1, 0, 0), SIMD4(0, 1, 0, 1.5),
        // Head on, the ray goes straight through.
        SIMD4(0, -1, 0, 0), SIMD4(0, 1, 0, 1 / 1.5),
    ]
    let out = try TestGPU().run("test_refract", threads: 2, inputs: [bytes(input)], outputs: [32])
    let refracted = values(out[0], as: SIMD4<Float>.self)
    #expect(refracted[0].w == 0)
    #expect(refracted[1].w == 1)
    let r = SIMD3(refracted[1].x, refracted[1].y, refracted[1].z)
    #expect(((r - SIMD3(0, -1, 0)) * (r - SIMD3(0, -1, 0))).sum() < 1e-12)
}
