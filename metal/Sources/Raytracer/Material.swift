public enum Material: Equatable, Sendable {
    case lambertian(albedo: Color)
    case metal(albedo: Color, fuzz: Double)
    case dielectric(refIndex: Double)

    /// `fuzz` is clamped to [0, 1]: 0 is a perfect mirror.
    public static func metal(_ albedo: Color, fuzz: Double) -> Material {
        .metal(albedo: albedo, fuzz: min(max(fuzz, 0), 1))
    }
}
