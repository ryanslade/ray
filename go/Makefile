help:
	@echo "make build    builds it"
	@echo "make test     runs the tests"
	@echo "make example  renders the example scene to example/out.png"
	@echo "make clean    removes the build output"

build:
	go build ./...

test:
	go test ./...

# Renders the example scene to example/out.png. On arm64,
# `make example GOEXPERIMENT=simd` tests spheres two at a time with NEON.
example:
	cd example && go run .

clean:
	go clean ./...

.PHONY: help build test example clean
