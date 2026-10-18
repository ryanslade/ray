A simple ray tracer, implemented in Go, OCaml, Rust, Zig, C, Janet, Clojure,
Kotlin and Scala, and on the GPU with Metal.

This project was based on the book, [Ray Tracing in One Weekend](https://www.amazon.com/Ray-Tracing-Weekend-Minibooks-Book-ebook/dp/B01B5AODD8)

- [`go/`](go) — the original Go implementation
- [`ocaml/`](ocaml) — a port to OCaml 5, rendering in parallel across domains
- [`rust/`](rust) — a port to Rust, using only the standard library and no `unsafe`
- [`zig/`](zig) — a port to Zig, producing byte-identical images to the Rust port
- [`c/`](c) — a port to C11 with pthreads, also byte-identical to the Rust port
- [`janet/`](janet) — a port to Janet, rendering rows on parallel OS threads
- [`clojure/`](clojure) — a port to Clojure on the JVM, also byte-identical to the
  Rust port
- [`kotlin/`](kotlin) — a port to Kotlin on the JVM, byte-identical as well
- [`scala/`](scala) — a port to Scala 3 on the JVM, also byte-identical
- [`metal/`](metal) — a port to Metal compute shaders, driven from Swift, rendering
  every pixel on its own GPU thread

An example of an image created using this library:

![Sample](/go/sample/sample.png "Sample")

## Running

Each port has a Makefile with the same targets:

```sh
cd rust      # or go, ocaml, zig, c, janet, clojure, kotlin, scala, metal
make build   # builds it
make test    # runs the tests
make example # renders the example scene to out.ppm, or another path with OUT=
make clean   # removes the build output
```

Running `make` by itself lists the targets.

The Go example writes `example/out.jpg` instead. On arm64,
`make example GOEXPERIMENT=simd` tests spheres two at a time with NEON, which
makes the example scene about 3.4x faster.

Each port needs:

- Go: the version in `go/go.mod`
- OCaml: OCaml >= 5.5 and the dependencies from
  `opam install . --deps-only --with-test`
- Rust: the toolchain pinned in `rust/rust-toolchain.toml`
- Zig: Zig 0.16
- C: a C11 compiler with pthreads, such as GCC or Clang
- Janet: Janet >= 1.41
- Clojure: Java >= 25 and the Clojure CLI
- Kotlin: Java >= 17 to run Gradle, which downloads Java 25 if it isn't
  installed
- Scala: only curl, since `scala/mill` downloads Mill, which downloads Java 25
- Metal: macOS 15 and Swift 6

The Metal shader is compiled when the program starts, so Xcode isn't needed,
only the Command Line Tools. They include Swift Testing, but `swift test`
doesn't find it without Xcode, so `make test` passes it the paths it needs
when the Command Line Tools are selected.

## Performance

All ten implementations render the same random scene (about 480 spheres) at
800x450 with 100 samples per pixel. The CPU versions split rows across all
cores; the Metal version runs on the GPU.
Measured on an Apple M1 Max (10 CPU cores, 32 GPU cores), Go 1.27.2, OCaml
5.5.1 (no flambda), Rust 1.99.1, Zig 0.16.0, Apple clang 21.0.0, Janet 1.41.2,
Clojure 1.12.6, Kotlin 2.4.21 and Scala 3.10.0 on OpenJDK 25.0.4, Swift 6.3.3 on
macOS 26:

| Benchmark                                  | Go     | OCaml   | Rust   | Zig    | C      | Janet  | Clojure | Kotlin | Scala  | Metal  |
| ------------------------------------------ | ------ | ------- | ------ | ------ | ------ | ------ | ------- | ------ | ------ | ------ |
| Example scene, 800x450, 100 spp (wall)     | 20.3 s | 35.4 s  | 8.3 s  | 8.5 s  | 7.1 s  | 400 s  | 18.1 s  | 8.9 s  | 9.1 s  | 0.8 s  |
| Example scene, 800x450, 100 spp (CPU)      | 175 s  | 305 s   | 75 s   | 82 s   | 62 s   | 3871 s | 166 s   | 84 s   | 86 s   | (GPU)  |
| Test scene, 100x100, 50 spp (per render)   | 13 ms  | 26 ms   | 5 ms   | 5.4 ms | 5.2 ms | 455 ms | 9.1 ms  | 8.9 ms | 10 ms  | 3.3 ms |

With `GOEXPERIMENT=simd`, the Go example scene takes 5.9 s (wall)
and 50 s (CPU).

The test scene benchmark is `go test -bench Render` in `go/`,
`dune exec --release bench/bench.exe` in `ocaml/`, `cargo bench` in `rust/`,
`zig build bench -Doptimize=ReleaseFast` in `zig/`, `make bench` in `c/`,
`janet bench.janet` in `janet/`, `clojure -M:bench` in `clojure/`,
`./gradlew bench` in `kotlin/`, `./mill bench` in `scala/` and
`swift run -c release bench` in `metal/`.

The OCaml version allocates short-lived vectors throughout (including one for
every ray/sphere test), where Go keeps them on the stack. In OCaml 5 every
minor collection pauses all domains, so the allocation rate limits scaling;
raising the minor heap (e.g. `OCAMLRUNPARAM=s=8M`) cuts the
OCaml example time by around a third.

The OCaml render of the example scene:

![OCaml sample](/ocaml/sample/sample.png "OCaml sample")

Rust keeps vectors on the stack like Go, but materials are a plain enum rather
than closures, so scattering is a `match` instead of an indirect call. Finding
the closest hit only computes the hit point and normal for the winning sphere,
and each bounce is a loop iteration rather than a recursive call.

The Rust render of the example scene:

![Rust sample](/rust/sample/sample.png "Rust sample")

The Zig port follows the Rust one closely: the same SplitMix64 generator, a
tagged union for materials, a loop for bounces, and the same order of floating
point operations. Its renders are byte-identical to Rust's, so its golden image
is a copy of Rust's and the Rust sample above is also the Zig render. Threads
take rows from an atomic counter rather than a mutex-guarded iterator.

The C port is built the same way again: SplitMix64, a tagged union for
materials, a bounce loop and the same order of floating point operations, so
its renders are byte-identical to Rust's as well (the example scene with Clang
and GCC on macOS, and the test scene there and with GCC on arm64 and x86-64
Linux). It compiles with `-ffp-contract=off`, so the compiler can't fuse
multiplies and adds into single-rounding FMA instructions that Rust never
emits; in practice fusing didn't change a single byte of either scene with
Clang, but nothing guarantees that.
Threads are pthreads taking rows from a C11 atomic counter. It builds with
`-O3 -flto` by default: link-time optimisation inlines hit testing, scattering
and camera rays across source files, which makes a single-threaded render of
the test scene about 20% faster.

Janet is a bytecode interpreter, so it is by far the slowest. Each thread is a
separate Janet VM with its own heap, so there is no shared garbage collector to
limit scaling; the world and camera are copied to each thread, which takes rows
from a channel and sends back finished rows. Vectors are tuples, but the
closest-hit loop works on plain numbers from a flat array of sphere centres and
radii, which makes the example scene about five times faster than calling a
per-sphere intersection function.

The Janet render of the example scene:

![Janet sample](/janet/sample/sample.png "Janet sample")

The Clojure port runs on the JVM, and its renders are byte-identical to Rust's
too. Since Java 17 all floating point arithmetic is strict IEEE 754, so the same
order of operations gives the same results; the camera's one tangent uses
`StrictMath`, whose results don't depend on the JVM's intrinsics. Vectors are a
`deftype` with primitive double fields rather than Clojure vectors, and the
SplitMix64 generator is a `deftype` with a mutable long, behind an interface
with primitive signatures. Every namespace warns on reflection and boxed maths,
so the hot path has neither. Materials are records implementing a protocol, and
a missed intersection returns NaN rather than nil, so the closest-hit loop
works on unboxed doubles. Threads are futures taking rows from an atomic
counter. Every alias in `deps.edn` turns on direct linking, which compiles calls
between functions to static method calls that the JIT can inline; that makes
the test scene about 1.8x faster. The example scene's time includes about a
second of starting the JVM and compiling the Clojure source, and the benchmark
warms up the JIT for three seconds before timing.

The Kotlin port is the closest to the Rust one in shape: vectors and colours
are small final classes with operator overloads, materials are a sealed
interface matched with `when`, and the generator works on `ULong`s, whose
arithmetic wraps like Rust's `wrapping_mul`. Like the Clojure port it relies on
strict IEEE 754 arithmetic and `StrictMath.tan`, and its renders are
byte-identical to Rust's. Every vector operation creates a new object, yet the
example scene runs only about 7% slower than Rust's, twice as fast as the
Clojure port; on the test scene, with only three spheres, the two JVM ports are
much closer. Gradle builds with compiler warnings as errors and checks
formatting with ktlint. The benchmark runs from the test classes, after the
same three second warm-up.

The Scala port is the Kotlin one in Scala 3: vectors and colours are case
classes with symbolic operators, plus an extension method on `Double` for
scaling on the left, and materials are an enum taken apart with `match`. The
generator works on plain `Long`s, whose arithmetic wraps, with `>>>` for the
unsigned shifts. Scattering and the closest hit return `Option`s, and the
bounce loop is a `@tailrec` function that the compiler turns into a loop. Its
renders are byte-identical to Rust's. One trap: `t.isNaN` on a `Double`
compiles to a conversion to `java.lang.Double` so as to call its `isNaN`
method, boxing the result of every ray/sphere test; calling
`java.lang.Double.isNaN(t)` instead makes the example scene 2.5x faster. Mill
builds it with compiler warnings as errors and checks formatting with
scalafmt. The `mill` launcher script downloads Mill, which downloads Java 25,
so nothing needs installing first. The benchmark runs from the test classes,
after the same three second warm-up.

The Metal version traces every pixel on its own GPU thread. The Swift host
builds the scene and camera in double precision exactly as the other versions
do, then hands them to a compute shader, which works in single precision: Apple
GPUs have no doubles. It keeps the SplitMix64 generator (the GPU emulates the
64-bit multiplies, but they cost little next to the intersection tests), seeded
per pixel rather than per row, and the same closest-hit loop, materials and
bounce loop as the Rust version. The spheres sit in Metal's `constant` address
space; every thread in a SIMD group tests the same sphere at the same time, so
each is fetched once for the group.

Its renders aren't byte-identical to the CPU versions', since the precision
and random numbers differ. Instead the tests compare its render of the test
scene with the CPU versions' golden image averaged over 10x10 blocks, which
smooths out the noise but still catches a material, the sky or the bounce limit
behaving differently. Samples are traced in passes of 10, each its own command
buffer, so that no one command buffer runs long enough for the GPU watchdog to
cancel it. Each pixel's random state and running total carry over between
passes, so the image is the same however the samples are split up. The example
scene renders in about 0.8 s, including compiling the shader, nearly nine times
faster than the C version on all ten CPU cores. The test scene, at only 10,000
pixels, is too small to keep the GPU busy, so the gap there is much smaller.

The Metal render of the example scene:

![Metal sample](/metal/sample/sample.png "Metal sample")
