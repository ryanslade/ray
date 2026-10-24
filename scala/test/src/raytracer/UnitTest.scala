package raytracer

class UnitTest extends munit.FunSuite:
  private def assertClose(expected: Vec3, actual: Vec3)(using munit.Location): Unit =
    assert((expected - actual).length < 1e-9, s"$actual != $expected")

  test("vec3 arithmetic") {
    val a = Vec3(1, 2, 3)
    val b = Vec3(4, 5, 6)
    assertClose(Vec3(5, 7, 9), a + b)
    assertClose(Vec3(2, 4, 6), 2.0 * a)
    assertEquals(a.dot(b), 32.0)
    assertClose(Vec3(-3, 6, -3), a.cross(b))
    assert(math.abs(b.unit.length - 1.0) < 1e-9)
  }

  test("floats in unit interval") {
    val rng = Rng(1)
    for _ <- 1 to 10_000 do
      val f = rng.nextDouble()
      assert(f >= 0.0 && f < 1.0, f)
  }

  test("same seed, same sequence") {
    val a = Rng(42)
    val b = Rng(42)
    for _ <- 1 to 100 do assertEquals(a.nextLong(), b.nextLong())
  }

  test("sphere hit") {
    val m = Material.dielectric(1.5)
    val s = Sphere(Vec3(0, 0, -1), 0.5, m)
    val towards = Ray(Vec3.Zero, Vec3(0, 0, -1))

    val h = s.hit(towards, 0, Double.PositiveInfinity).get
    assertEquals(h.t, 0.5)
    assertEquals(h.normal, Vec3(0, 0, 1))
    assert(h.material eq m)

    assertEquals(s.hit(towards, 0.6, Double.PositiveInfinity).map(_.t), Some(1.5), "far side")

    val away = Ray(Vec3.Zero, Vec3(0, 1, 0))
    assertEquals(s.hit(away, 0, Double.PositiveInfinity), None)
  }

  test("closest hit") {
    val m = Material.dielectric(1.5)
    val world = World(
      Seq(
        Sphere(Vec3(0, 0, -5), 1, m),
        Sphere(Vec3(0, 0, -2), 0.5, m)
      )
    )
    val ray = Ray(Vec3.Zero, Vec3(0, 0, -1))
    assertEquals(world.hit(ray, 0, Double.PositiveInfinity).map(_.t), Some(1.5))
    assertEquals(world.hit(Ray(Vec3.Zero, Vec3(0, 1, 0)), 0, Double.PositiveInfinity), None)
  }

  test("total internal reflection") {
    val n = Vec3(0, 1, 0)
    val grazing = Vec3(1, -0.1, 0)
    assertEquals(refract(grazing, n, 1.5), None)
  }

  test("refracts head on") {
    val n = Vec3(0, 1, 0)
    val down = Vec3(0, -1, 0)
    assertClose(down, refract(down, n, 1.0 / 1.5).get)
  }

  test("metal fuzz is clamped") {
    assertEquals(Material.metal(Color.White, 2), Material.Metal(Color.White, 1))
    assertEquals(Material.metal(Color.White, -1), Material.Metal(Color.White, 0))
  }

  test("update clamps") {
    val img = Image(3, 1)
    img(1, 0) = Color(2, 0.5, -1)
    // f64::min in Rust ignores NaN, so NaN becomes 255.
    img(2, 0) = Color(Double.NaN, 0, 0)
    assertEquals(img(0, 0), (0, 0, 0))
    assertEquals(img(1, 0), (255, 127, 0))
    assertEquals(img(2, 0), (255, 0, 0))
    intercept[IndexOutOfBoundsException](img(3, 0))
  }

  test("ppm header") {
    val ppm = Image(3, 2).toPpm
    assertEquals(String(ppm, 0, 11, "US-ASCII"), "P6\n3 2\n255\n")
    assertEquals(ppm.length, 11 + 3 * 2 * 3)
  }

  test("png round trip") {
    val img = Image(4, 3)
    for y <- 0 until 3; x <- 0 until 4 do img(x, y) = Color(x / 4.0, y / 3.0, (x + y) % 7 / 7.0)
    val f = java.io.File.createTempFile("raytracer", ".png")
    try
      img.savePng(f.getPath)
      val bi = javax.imageio.ImageIO.read(f)
      assertEquals((bi.getWidth, bi.getHeight), (4, 3))
      // PNG is lossless, so every pixel comes back unchanged.
      for y <- 0 until 3; x <- 0 until 4 do
        val rgb = bi.getRGB(x, y)
        assertEquals((rgb >> 16 & 0xff, rgb >> 8 & 0xff, rgb & 0xff), img(x, y))
    finally f.delete()
  }
