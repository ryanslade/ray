# Needs Racket >= 9: the full distribution, or minimal Racket with
# `raco pkg install rackunit-lib compiler-lib`.

OUT ?= out.png

help:
	@echo "make build    builds it"
	@echo "make test     runs the tests"
	@echo "make example  renders the example scene to $(OUT), or another path with OUT="
	@echo "make bench    runs the benchmark, with ARGS=\"iterations threads\""
	@echo "make clean    removes the build output"

# An executable with the compiled modules embedded, which runs where Racket is
# installed.
build:
	raco make -v main.rkt
	mkdir -p build
	raco exe -o build/raytracer main.rkt

test:
	raco make -v test/*.rkt
	raco test test

# Renders the example scene to $(OUT).
example: build
	build/raytracer $(OUT)

# `make bench ARGS="iterations threads"` overrides the defaults of 20
# iterations on every core.
bench:
	raco make -v bench/bench.rkt
	racket bench/bench.rkt $(ARGS)

clean:
	rm -rf build compiled src/compiled test/compiled bench/compiled \
		test/golden.actual.ppm

.PHONY: help build test example bench clean
