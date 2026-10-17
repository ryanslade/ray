A simple ray tracer, implemented in both Go and OCaml.

This project was based on the book, [Ray Tracing in One Weekend](https://www.amazon.com/Ray-Tracing-Weekend-Minibooks-Book-ebook/dp/B01B5AODD8)

- [`go/`](go) — the original Go implementation
- [`ocaml/`](ocaml) — a port to OCaml 5, rendering in parallel across domains

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

## Performance

Both implementations render the same random scene (about 480 spheres) at
800x450 with 100 samples per pixel, splitting rows across all cores.
Measured on an Apple M1 Max (10 cores), Go 1.25.5, OCaml 5.5.1 (no flambda):

| Benchmark                                  | Go     | OCaml   |
| ------------------------------------------ | ------ | ------- |
| Example scene, 800x450, 100 spp (wall)     | 21.3 s | 35.4 s  |
| Example scene, 800x450, 100 spp (CPU)      | 205 s  | 305 s   |
| Test scene, 100x100, 50 spp (per render)   | 26 ms  | 26 ms   |

The test scene benchmark is `go test -bench .` in `go/` and
`dune exec --release bench/bench.exe` in `ocaml/`.

The OCaml version is on par for the small test scene but slower on the large
one, where it allocates a short-lived vector for every ray/sphere test. In
OCaml 5 every minor collection pauses all domains, so the allocation rate
limits scaling; raising the minor heap (e.g. `OCAMLRUNPARAM=s=8M`) cuts the
OCaml example time by around a third.

The OCaml render of the example scene:

![OCaml sample](/ocaml/sample/sample.png "OCaml sample")
