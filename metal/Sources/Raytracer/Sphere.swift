public struct Sphere: Equatable, Sendable {
    public var center: Vec3
    public var radius: Double
    public var material: Material

    public init(center: Vec3, radius: Double, material: Material) {
        self.center = center
        self.radius = radius
        self.material = material
    }
}
