# Needs Zig 0.16.

OUT ?= out.ppm

build:
	zig build -Doptimize=ReleaseFast

test:
	zig build test

# Renders the example scene to $(OUT).
example:
	zig build run -Doptimize=ReleaseFast -- $(OUT)

.PHONY: build test example
