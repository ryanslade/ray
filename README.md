A simple ray tracer, implemented in Go, OCaml, Rust, Zig, C and Janet.

This project was based on the book, [Ray Tracing in One Weekend](https://www.amazon.com/Ray-Tracing-Weekend-Minibooks-Book-ebook/dp/B01B5AODD8)

- [`go/`](go) — the original Go implementation
- [`ocaml/`](ocaml) — a port to OCaml 5, rendering in parallel across domains
- [`rust/`](rust) — a port to Rust, using only the standard library and no `unsafe`
- [`zig/`](zig) — a port to Zig, producing byte-identical images to the Rust port
- [`c/`](c) — a port to C11 with pthreads, also byte-identical to the Rust port
- [`janet/`](janet) — a port to Janet, rendering rows on parallel OS threads

An example of an image created using this library:

![Sample](/go/sample/sample.png "Sample")

## Running

Go (writes `out.jpg`):

```sh
cd go/example && go run .
```

On arm64 with Go 1.27, `GOEXPERIMENT=simd go run .` tests spheres two at a
time with NEON, which makes the example scene about 3.4x faster.

OCaml (requires OCaml >= 5.5; writes `out.ppm`):

```sh
cd ocaml
opam install . --deps-only --with-test
dune exec --release raytracer -- out.ppm
dune test
```

Rust (uses the toolchain pinned in `rust-toolchain.toml`; writes `out.ppm`):

```sh
cd rust
cargo run --release -- out.ppm
cargo test
```

Zig (requires Zig 0.16; writes `out.ppm`):

```sh
cd zig
zig build run -Doptimize=ReleaseFast -- out.ppm
zig build test
```

C (requires a C11 compiler with pthreads, such as GCC or Clang; writes
`out.ppm`, or another path with `OUT=`):

```sh
cd c
make run
make test
```

Janet (requires Janet >= 1.41; writes `out.ppm`):

```sh
cd janet
janet main.janet out.ppm
jpm test
```

## Performance

All six implementations render the same random scene (about 480 spheres) at
800x450 with 100 samples per pixel, splitting rows across all cores.
Measured on an Apple M1 Max (10 cores), Go 1.25.5, OCaml 5.5.1 (no flambda),
Rust 1.99.1, Zig 0.16.0, Apple clang 21.0.0, Janet 1.41.2:

| Benchmark                                  | Go     | OCaml   | Rust   | Zig    | C      | Janet  |
| ------------------------------------------ | ------ | ------- | ------ | ------ | ------ | ------ |
| Example scene, 800x450, 100 spp (wall)     | 21.3 s | 35.4 s  | 8.3 s  | 8.5 s  | 7.1 s  | 400 s  |
| Example scene, 800x450, 100 spp (CPU)      | 189 s  | 305 s   | 75 s   | 82 s   | 62 s   | 3871 s |
| Test scene, 100x100, 50 spp (per render)   | 13 ms  | 26 ms   | 5 ms   | 5.4 ms | 5.2 ms | 455 ms |

With Go 1.27.2 and `GOEXPERIMENT=simd`, the Go example scene takes 5.9 s (wall)
and 50 s (CPU).

The test scene benchmark is `go test -bench Render` in `go/`,
`dune exec --release bench/bench.exe` in `ocaml/`, `cargo bench` in `rust/`,
`zig build bench -Doptimize=ReleaseFast` in `zig/`, `make bench` in `c/` and
`janet bench.janet` in `janet/`.

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
