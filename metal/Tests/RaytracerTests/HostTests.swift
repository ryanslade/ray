import Foundation
import Raytracer
import Testing

@Test func rngFloatsInUnitInterval() {
    var rng = Rng(seed: 1)
    for _ in 0..<10000 {
        let f = rng.next()
        #expect(f >= 0 && f < 1)
    }
}

@Test func rngSameSeedSameSequence() {
    var a = Rng(seed: 42)
    var b = Rng(seed: 42)
    for _ in 0..<100 {
        #expect(a.nextU64() == b.nextU64())
    }
}

@Test func metalFuzzIsClamped() {
    #expect(Material.metal(Color(1, 1, 1), fuzz: 2) == .metal(albedo: Color(1, 1, 1), fuzz: 1))
    #expect(Material.metal(Color(1, 1, 1), fuzz: -1) == .metal(albedo: Color(1, 1, 1), fuzz: 0))
}

@Test func imageSetClamps() {
    var img = Image(width: 2, height: 1)
    img.set(1, 0, Color(2, 0.5, -1))
    img.set(0, 0, Color(.nan, 0, 0))
    #expect(img.get(0, 0) == [0, 0, 0])
    #expect(img.get(1, 0) == [255, 127, 0])
}

@Test func ppmHeader() {
    let ppm = Image(width: 3, height: 2).ppm()
    #expect(ppm.count == 11 + 3 * 2 * 3)
    #expect(ppm.prefix(11) == Data("P6\n3 2\n255\n".utf8))
}
