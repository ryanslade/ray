# Needs GHC 9.14, as ghc-9.14 (`ghcup install ghc 9.14.1`), and cabal >= 3.12.

OUT ?= out.png

help:
	@echo "make build    builds it"
	@echo "make test     runs the tests"
	@echo "make example  renders the example scene to $(OUT), or another path with OUT="
	@echo "make bench    runs the benchmark, with ARGS=\"iterations threads\""
	@echo "make clean    removes the build output"

build:
	cabal build exe:raytracer

test:
	cabal test --test-show-details=direct

# Renders the example scene to $(OUT).
example:
	cabal run -v0 exe:raytracer -- $(OUT)

# `make bench ARGS="iterations threads"` overrides the defaults of 20
# iterations on every core.
bench:
	cabal bench -v1 --benchmark-options="$(ARGS)"

clean:
	cabal clean
	rm -f test/golden.actual.ppm

.PHONY: help build test example bench clean
