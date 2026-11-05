# Needs jank 0.1 (brew install jank-lang/jank/jank) and zlib.

OUT ?= out.png

SOURCES := $(shell find src test bench -name '*.jank' -o -name '*.hpp')
JANK := jank compile --module-path src:test:bench -I src -O 3 -lz --target-dir target

help:
	@echo "make build    builds it"
	@echo "make test     runs the tests"
	@echo "make example  renders the example scene to $(OUT), or another path with OUT="
	@echo "make bench    runs the benchmark, with ARGS=\"iterations threads\""
	@echo "make clean    removes the build output"

build: target/raytracer

# jank's build cache doesn't notice when a module that another depends on
# changes (a macro, say), so each program is compiled from scratch.
target/%: $(SOURCES)
	rm -rf target/$*.cache
	$(JANK) --build-dir target/$*.cache --name $* $(MODULE)

target/raytracer: MODULE := raytracer.main
target/test: MODULE := raytracer.test-main
target/bench: MODULE := raytracer.bench

test: target/test
	target/test

# Renders the example scene to $(OUT).
example: target/raytracer
	target/raytracer $(OUT)

bench: target/bench
	target/bench $(ARGS)

clean:
	rm -rf target out.png test/golden.actual.ppm

.PHONY: help build test example bench clean
