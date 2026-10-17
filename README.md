A simple ray tracer, implemented in Go, OCaml and Rust.

This project was based on the book, [Ray Tracing in One Weekend](https://www.amazon.com/Ray-Tracing-Weekend-Minibooks-Book-ebook/dp/B01B5AODD8)

- [`go/`](go) — the original Go implementation
- [`ocaml/`](ocaml) — a port to OCaml 5, rendering in parallel across domains
- [`rust/`](rust) — a port to Rust, using only the standard library and no `unsafe`

An example of an image created using this library:

![Sample](/go/sample/sample.png "Sample")

## Running

Go (writes `out.jpg`):

```sh
cd go/example && go run .
```

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

## Performance

All three implementations render the same random scene (about 480 spheres) at
800x450 with 100 samples per pixel, splitting rows across all cores.
Measured on an Apple M1 Max (10 cores), Go 1.25.5, OCaml 5.5.1 (no flambda),
Rust 1.99.1:

| Benchmark                                  | Go     | OCaml   | Rust   |
| ------------------------------------------ | ------ | ------- | ------ |
| Example scene, 800x450, 100 spp (wall)     | 21.3 s | 35.4 s  | 8.3 s  |
| Example scene, 800x450, 100 spp (CPU)      | 189 s  | 305 s   | 75 s   |
| Test scene, 100x100, 50 spp (per render)   | 13 ms  | 26 ms   | 5 ms   |

The test scene benchmark is `go test -bench .` in `go/`,
`dune exec --release bench/bench.exe` in `ocaml/` and `cargo bench` in `rust/`.

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
