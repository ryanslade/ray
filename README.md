A simple ray tracer based on
[Ray Tracing in One Weekend](https://www.amazon.com/Ray-Tracing-Weekend-Minibooks-Book-ebook/dp/B01B5AODD8),
ported to fourteen languages and to the GPU.

![Sample](/go/sample/sample.png "Sample")

## Ports

Each port renders the same scene: about 480 spheres at 800x450 with 100 samples
per pixel. Times were measured on an Apple M1 Max (10 CPU cores, 32 GPU cores).
The CPU ports split rows across all cores. Lines of code don't count blank
lines, comments, tests or benchmarks.

| Port                          | Notes                                 | Example scene | Lines of code |
| ----------------------------- | ------------------------------------- | ------------: | ------------: |
| [Metal](metal)                | GPU compute shader, driven from Swift |         0.8 s |           562 |
| [Zig](zig)                    | SIMD via `@Vector`                    |         4.3 s |           641 |
| [C](c)                        | C11 and pthreads                      |         5.3 s |           797 |
| [Rust](rust)                  | Standard library only, no `unsafe`    |         5.4 s |           746 |
| [Go](go)                      | The original                          |         7.9 s |           554 |
| [Common Lisp](common-lisp)    | SBCL                                  |         8.0 s |           607 |
| [Kotlin](kotlin)              | JVM                                   |         8.9 s |           482 |
| [Scala](scala)                | Scala 3 on the JVM                    |         9.1 s |           323 |
| [Racket](racket)              | Racket CS, parallel futures           |        13.2 s |           522 |
| [OCaml](ocaml)                | OCaml 5, parallel domains             |        13.4 s |           297 |
| [Haskell](haskell)            | GHC, pure, with `parMap` over rows    |        15.7 s |           497 |
| [Clojure](clojure)            | JVM                                   |        18.1 s |           434 |
| [Elixir](elixir)              | One BEAM process per row              |         155 s |           531 |
| [Erlang](erlang)              | A pool of one process per core        |         160 s |           586 |
| [Janet](janet)                | Bytecode interpreter, OS threads      |         400 s |           439 |

Apart from Go, OCaml, Janet and Metal, every port's renders are byte-identical
to Rust's.

## Running

Each port has a Makefile with the same targets:

```sh
cd rust      # or any other port
make build   # builds it
make test    # runs the tests
make example # renders the example scene
make clean   # removes the build output
```
