import Foundation

/// An 8-bit RGB image. Row 0 is the top.
public struct Image: Equatable, Sendable {
    public let width: Int
    public let height: Int
    /// The RGB bytes of each pixel, row by row.
    public private(set) var pixels: [UInt8]

    /// A black image.
    public init(width: Int, height: Int) {
        precondition(width >= 0 && height >= 0)
        self.width = width
        self.height = height
        pixels = [UInt8](repeating: 0, count: width * height * 3)
    }

    private func index(_ x: Int, _ y: Int) -> Int {
        precondition(x >= 0 && x < width && y >= 0 && y < height)
        return (y * width + x) * 3
    }

    /// Stores a colour, clamping each channel to [0, 1].
    public mutating func set(_ x: Int, _ y: Int, _ c: Color) {
        let i = index(x, y)
        pixels[i] = Self.toByte(c.x)
        pixels[i + 1] = Self.toByte(c.y)
        pixels[i + 2] = Self.toByte(c.z)
    }

    public func get(_ x: Int, _ y: Int) -> [UInt8] {
        let i = index(x, y)
        return Array(pixels[i..<i + 3])
    }

    private static func toByte(_ v: Double) -> UInt8 {
        // Written so that NaN becomes 0, like a saturating cast in Rust.
        guard v > 0 else { return 0 }
        return UInt8(255.99 * min(v, 1))
    }

    /// The image in binary (P6) PPM format.
    public func ppm() -> Data {
        var data = Data("P6\n\(width) \(height)\n255\n".utf8)
        data.append(contentsOf: pixels)
        return data
    }

    public func save(to path: String) throws {
        try ppm().write(to: URL(fileURLWithPath: path))
    }
}
