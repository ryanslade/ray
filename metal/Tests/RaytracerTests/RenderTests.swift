import Foundation
import Raytracer
import TestScene
import Testing

@Test func deterministicAcrossPasses() throws {
    let (width, height) = (40, 30)
    let camera = testCamera(width: width, height: height)
    let renderer = try Renderer()
    func render(_ samplesPerPass: Int) throws -> Image {
        try renderer.render(
            width: width, height: height, samples: 8, camera: camera, world: testWorld(),
            samplesPerPass: samplesPerPass)
    }
    let expected = try render(8)
    for samplesPerPass in [1, 3, 5] {
        #expect(try render(samplesPerPass) == expected, "\(samplesPerPass) samples per pass")
    }
}

/// The pixels of a binary PPM file.
private func readPPM(_ data: Data, width: Int, height: Int) throws -> [UInt8] {
    let header = Data("P6\n\(width) \(height)\n255\n".utf8)
    try #require(data.count == header.count + width * height * 3)
    try #require(data.prefix(header.count) == header)
    return Array(data.dropFirst(header.count))
}

/// Renders the test scene and compares it with `reference.ppm`, a copy of the
/// CPU versions' golden image.
///
/// The GPU works in single precision with different random numbers, so the
/// noise differs from pixel to pixel. Averaged over 10x10 blocks, though, the
/// images should agree closely; a real difference (say a material behaving
/// differently) shows up as blocks far apart. On a mismatch the render is
/// written to `golden.actual.ppm` in the temporary directory.
@Test func matchesCPUVersions() throws {
    let (width, height, block) = (200, 200, 10)
    let img = try Renderer().render(
        width: width, height: height, samples: 100,
        camera: testCamera(width: width, height: height),
        world: testWorld())
    let url = try #require(Bundle.module.url(forResource: "reference", withExtension: "ppm"))
    let reference = try readPPM(Data(contentsOf: url), width: width, height: height)

    var worst = 0.0
    var total = 0.0
    for by in stride(from: 0, to: height, by: block) {
        for bx in stride(from: 0, to: width, by: block) {
            for channel in 0..<3 {
                var diff = 0
                for y in by..<by + block {
                    for x in bx..<bx + block {
                        let i = (y * width + x) * 3 + channel
                        diff += Int(img.pixels[i]) - Int(reference[i])
                    }
                }
                let mean = abs(Double(diff)) / Double(block * block)
                worst = max(worst, mean)
                total += mean
            }
        }
    }
    let average = total / Double(width / block * height / block * 3)
    let ok = worst < 4 && average < 1
    if !ok {
        let out = FileManager.default.temporaryDirectory.appending(path: "golden.actual.ppm")
        try img.save(to: out.path)
        Issue.record("blocks differ by up to \(worst) and \(average) on average; wrote \(out.path)")
    }
}
