# Uses the toolchain pinned in rust-toolchain.toml.

OUT ?= out.png

help:
	@echo "make build    builds it"
	@echo "make test     runs the tests"
	@echo "make example  renders the example scene to $(OUT), or another path with OUT="
	@echo "make clean    removes the build output"

build:
	cargo build --release

test:
	cargo test

# Renders the example scene to $(OUT).
example:
	cargo run --release -- $(OUT)

clean:
	cargo clean

.PHONY: help build test example clean
