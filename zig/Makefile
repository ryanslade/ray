# Needs Zig 0.16.

OUT ?= out.ppm

help:
	@echo "make build    builds it"
	@echo "make test     runs the tests"
	@echo "make example  renders the example scene to $(OUT), or another path with OUT="
	@echo "make clean    removes the build output"

build:
	zig build -Doptimize=ReleaseFast

test:
	zig build test

# Renders the example scene to $(OUT).
example:
	zig build run -Doptimize=ReleaseFast -- $(OUT)

clean:
	rm -rf .zig-cache zig-out tests/golden.actual.ppm

.PHONY: help build test example clean
