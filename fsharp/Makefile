# Needs the .NET 10 SDK, e.g. with `mise install` (see mise.toml). Fantomas, the
# formatter, is a local tool: `dotnet tool restore && dotnet fantomas .`.

OUT ?= out.png

help:
	@echo "make build    builds it"
	@echo "make test     runs the tests"
	@echo "make example  renders the example scene to $(OUT), or another path with OUT="
	@echo "make bench    runs the benchmark, with ARGS=\"iterations threads\""
	@echo "make clean    removes the build output"

build:
	dotnet build -c Release

test:
	dotnet run -c Release --project test/Raytracer.Tests

# Renders the example scene to $(OUT).
example:
	dotnet run -c Release --project src/Raytracer.Cli -- $(OUT)

# `make bench ARGS="iterations threads"` overrides the defaults of 20
# iterations on every core.
bench:
	dotnet run -c Release --project bench/Raytracer.Bench -- $(ARGS)

clean:
	rm -rf artifacts test/Raytracer.Tests/golden.actual.ppm

.PHONY: help build test example bench clean
