# Needs OCaml >= 5.5: `opam install . --deps-only --with-test`.

OUT ?= out.png

help:
	@echo "make build    builds it"
	@echo "make test     runs the tests"
	@echo "make example  renders the example scene to $(OUT), or another path with OUT="
	@echo "make clean    removes the build output"

build:
	dune build --release

test:
	dune test --force

# Renders the example scene to $(OUT).
example:
	dune exec --release raytracer -- $(OUT)

clean:
	dune clean

.PHONY: help build test example clean
