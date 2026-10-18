build:
	go build ./...

test:
	go test ./...

# Renders the example scene to example/out.jpg. On arm64,
# `make example GOEXPERIMENT=simd` tests spheres two at a time with NEON.
example:
	cd example && go run .

.PHONY: build test example
