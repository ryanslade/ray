import Foundation
import simd

/// Settings for `Camera.init`.
public struct CameraSettings: Sendable {
    public var lookFrom: Vec3
    public var lookAt: Vec3
    public var vUp: Vec3
    /// Vertical field of view in degrees.
    public var vfov: Double
    public var aspect: Double
    public var aperture: Double
    public var focusDist: Double

    public init(
        lookFrom: Vec3, lookAt: Vec3, vUp: Vec3, vfov: Double, aspect: Double, aperture: Double,
        focusDist: Double
    ) {
        self.lookFrom = lookFrom
        self.lookAt = lookAt
        self.vUp = vUp
        self.vfov = vfov
        self.aspect = aspect
        self.aperture = aperture
        self.focusDist = focusDist
    }
}

public struct Camera: Sendable {
    public let origin: Vec3
    public let lowerLeft: Vec3
    public let horizontal: Vec3
    public let vertical: Vec3
    public let u: Vec3
    public let v: Vec3
    public let lensRadius: Double

    public init(_ s: CameraSettings) {
        let theta = s.vfov * (Double.pi / 180)
        let halfHeight = tan(theta / 2)
        let halfWidth = s.aspect * halfHeight
        let w = normalize(s.lookFrom - s.lookAt)
        let u = normalize(cross(s.vUp, w))
        let v = cross(w, u)
        origin = s.lookFrom
        lowerLeft =
            s.lookFrom - u * (halfWidth * s.focusDist) - v * (halfHeight * s.focusDist)
            - w * s.focusDist
        horizontal = u * (2 * halfWidth * s.focusDist)
        vertical = v * (2 * halfHeight * s.focusDist)
        self.u = u
        self.v = v
        lensRadius = s.aperture / 2
    }
}
