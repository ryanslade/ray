// The host's copies of the structs in Shaders.metal. Swift doesn't promise to
// lay out structs in declaration order, so the tests check every offset
// against the ones the shader compiler reports.

/// Mirrors `Material`.
struct GPUMaterial {
    var albedo: SIMD3<Float>
    var param: Float
    var kind: UInt32

    init(_ m: Material) {
        switch m {
        case .lambertian(let albedo):
            self.init(albedo: SIMD3(albedo), param: 0, kind: 0)
        case .metal(let albedo, let fuzz):
            self.init(albedo: SIMD3(albedo), param: Float(fuzz), kind: 1)
        case .dielectric(let refIndex):
            self.init(albedo: .zero, param: Float(refIndex), kind: 2)
        }
    }

    init(albedo: SIMD3<Float>, param: Float, kind: UInt32) {
        self.albedo = albedo
        self.param = param
        self.kind = kind
    }
}

/// Mirrors `Camera`.
struct GPUCamera {
    var origin: SIMD3<Float>
    var lowerLeft: SIMD3<Float>
    var horizontal: SIMD3<Float>
    var vertical: SIMD3<Float>
    var u: SIMD3<Float>
    var v: SIMD3<Float>
    var lensRadius: Float

    init(_ c: Camera) {
        origin = SIMD3(c.origin)
        lowerLeft = SIMD3(c.lowerLeft)
        horizontal = SIMD3(c.horizontal)
        vertical = SIMD3(c.vertical)
        u = SIMD3(c.u)
        v = SIMD3(c.v)
        lensRadius = Float(c.lensRadius)
    }
}

/// Mirrors `Params`.
struct GPUParams {
    var width: UInt32
    var height: UInt32
    var sphereCount: UInt32
    var samples: UInt32
}

/// `Sphere` is a packed_float3 centre followed by the radius, the same layout
/// as a SIMD4<Float>.
func gpuSphere(_ s: Sphere) -> SIMD4<Float> {
    SIMD4(SIMD3<Float>(s.center), Float(s.radius))
}
