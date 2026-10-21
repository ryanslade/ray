# Needs Elixir >= 1.18 on Erlang/OTP >= 28.

OUT ?= out.ppm

help:
	@echo "make build    builds it"
	@echo "make test     runs the tests"
	@echo "make example  renders the example scene to $(OUT), or another path with OUT="
	@echo "make bench    runs the benchmark, with ARGS=\"iterations concurrency\""
	@echo "make clean    removes the build output"

# An escript, which runs on any Erlang installation.
build:
	mix escript.build

test:
	mix test --warnings-as-errors

# Renders the example scene to $(OUT).
example: build
	_build/raytracer $(OUT)

# `make bench ARGS="iterations concurrency"` overrides the defaults of 20
# iterations on every core.
bench:
	mix bench $(ARGS)

clean:
	rm -rf _build test/golden.actual.ppm

.PHONY: help build test example bench clean
