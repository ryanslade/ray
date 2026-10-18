# Uses the toolchain pinned in rust-toolchain.toml.

OUT ?= out.ppm

build:
	cargo build --release

test:
	cargo test

# Renders the example scene to $(OUT).
example:
	cargo run --release -- $(OUT)

.PHONY: build test example
