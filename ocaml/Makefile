# Needs OCaml >= 5.5: `opam install . --deps-only --with-test`.

OUT ?= out.ppm

build:
	dune build --release

test:
	dune test

# Renders the example scene to $(OUT).
example:
	dune exec --release raytracer -- $(OUT)

.PHONY: build test example
