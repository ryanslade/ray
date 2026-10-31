# Needs Erlang/OTP >= 28 and rebar3.

OUT ?= out.png

help:
	@echo "make build    builds it"
	@echo "make test     runs the tests"
	@echo "make example  renders the example scene to $(OUT), or another path with OUT="
	@echo "make bench    runs the benchmark, with ARGS=\"iterations processes\""
	@echo "make clean    removes the build output"

# An escript, which runs on any Erlang installation.
build:
	rebar3 escriptize

test:
	rebar3 eunit

# Renders the example scene to $(OUT).
example: build
	_build/default/bin/raytracer $(OUT)

# `make bench ARGS="iterations processes"` overrides the defaults of 20
# iterations on every core.
bench:
	rebar3 as test compile
	erl -noshell -pa _build/test/lib/raytracer/ebin _build/test/lib/raytracer/test \
		-run rt_bench main $(ARGS)

clean:
	rm -rf _build test/golden.actual.ppm

.PHONY: help build test example bench clean
