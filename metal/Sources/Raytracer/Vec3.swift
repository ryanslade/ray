/// The host works in double precision, like the CPU versions, so it builds
/// exactly the same scenes. Only the GPU uses single precision.
public typealias Vec3 = SIMD3<Double>

/// An RGB colour, each channel nominally in [0, 1].
public typealias Color = SIMD3<Double>
