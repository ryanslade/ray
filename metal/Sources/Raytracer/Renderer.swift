import Foundation
import Metal

public enum RenderError: Error, CustomStringConvertible {
    case noDevice
    case missingShaderSource
    case allocationFailed
    case commandFailed(Error?)

    public var description: String {
        switch self {
        case .noDevice: "no Metal device is available"
        case .missingShaderSource: "Shaders.metal is missing from the bundle"
        case .allocationFailed: "couldn't allocate a Metal buffer"
        case .commandFailed(let error?): "the GPU failed to render: \(error)"
        case .commandFailed(nil): "the GPU failed to render"
        }
    }
}

/// Renders on the GPU with Metal compute shaders.
public final class Renderer {
    public let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState

    /// Long-running command buffers can be cancelled by the GPU watchdog, so
    /// samples are traced in passes of at most this many, each its own
    /// command buffer.
    public static let defaultSamplesPerPass = 10

    /// The source of the shader, for compiling with extra test kernels.
    public static func shaderSource() throws -> String {
        guard let url = Bundle.module.url(forResource: "Shaders", withExtension: "metal") else {
            throw RenderError.missingShaderSource
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    public static func compileOptions() -> MTLCompileOptions {
        let options = MTLCompileOptions()
        options.languageVersion = .version3_1
        return options
    }

    public init(device: MTLDevice? = MTLCreateSystemDefaultDevice()) throws {
        guard let device, let queue = device.makeCommandQueue() else {
            throw RenderError.noDevice
        }
        let library = try device.makeLibrary(
            source: Self.shaderSource(), options: Self.compileOptions())
        self.device = device
        self.queue = queue
        pipeline = try device.makeComputePipelineState(
            function: library.makeFunction(name: "render")!)
    }

    private func buffer<T>(_ values: [T]) throws -> MTLBuffer {
        // Metal can't make empty buffers.
        let length = max(values.count, 1) * MemoryLayout<T>.stride
        let buffer = values.withUnsafeBytes { bytes in
            if let base = bytes.baseAddress {
                device.makeBuffer(bytes: base, length: length, options: .storageModeShared)
            } else {
                device.makeBuffer(length: length, options: .storageModeShared)
            }
        }
        guard let buffer else { throw RenderError.allocationFailed }
        return buffer
    }

    /// Renders the world with `samples` rays per pixel.
    ///
    /// Each pixel has its own random state, seeded from its index and carried
    /// from one pass to the next, so the image is the same however the
    /// samples are split into passes.
    public func render(
        width: Int, height: Int, samples: Int, camera: Camera, world: [Sphere],
        samplesPerPass: Int = defaultSamplesPerPass
    ) throws -> Image {
        precondition(samples >= 0 && samplesPerPass > 0)
        var img = Image(width: width, height: height)
        if width == 0 || height == 0 {
            return img
        }

        let pixelCount = width * height
        let spheres = try buffer(world.map(gpuSphere))
        let materials = try buffer(world.map { GPUMaterial($0.material) })
        let accum = try buffer([SIMD4<Float>](repeating: .zero, count: pixelCount))
        let rngStates = try buffer((0..<pixelCount).map { UInt64($0 + 1) })
        var gpuCamera = GPUCamera(camera)

        // Small square tiles keep the rays in a SIMD group close together,
        // so they tend to take the same branches.
        let group = MTLSize(width: 8, height: 8, depth: 1)
        let grid = MTLSize(width: width, height: height, depth: 1)
        var buffers: [MTLCommandBuffer] = []
        for start in stride(from: 0, to: samples, by: samplesPerPass) {
            guard let commands = queue.makeCommandBuffer(),
                let encoder = commands.makeComputeCommandEncoder()
            else {
                throw RenderError.commandFailed(nil)
            }
            var params = GPUParams(
                width: UInt32(width), height: UInt32(height), sphereCount: UInt32(world.count),
                samples: UInt32(min(samplesPerPass, samples - start)))
            encoder.setComputePipelineState(pipeline)
            encoder.setBytes(&params, length: MemoryLayout<GPUParams>.stride, index: 0)
            encoder.setBytes(&gpuCamera, length: MemoryLayout<GPUCamera>.stride, index: 1)
            encoder.setBuffer(spheres, offset: 0, index: 2)
            encoder.setBuffer(materials, offset: 0, index: 3)
            encoder.setBuffer(accum, offset: 0, index: 4)
            encoder.setBuffer(rngStates, offset: 0, index: 5)
            encoder.dispatchThreads(grid, threadsPerThreadgroup: group)
            encoder.endEncoding()
            commands.commit()
            buffers.append(commands)
        }
        // Buffers on one queue run in order, so waiting for the last waits for
        // them all.
        buffers.last?.waitUntilCompleted()
        if let failed = buffers.first(where: { $0.status != .completed }) {
            throw RenderError.commandFailed(failed.error)
        }

        let totals = accum.contents().bindMemory(to: SIMD4<Float>.self, capacity: pixelCount)
        let n = Double(samples)
        for y in 0..<height {
            for x in 0..<width {
                let total = totals[y * width + x]
                img.set(x, y, Color(Double(total.x), Double(total.y), Double(total.z)) / n)
            }
        }
        return img
    }
}
