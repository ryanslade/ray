# Needs only curl: ./mill downloads Mill, which downloads Java 25.

OUT ?= out.ppm

help:
	@echo "make build    builds it"
	@echo "make test     runs the tests"
	@echo "make example  renders the example scene to $(OUT), or another path with OUT="
	@echo "make clean    removes the build output"

build:
	./mill __.compile

test:
	./mill test

# Renders the example scene to $(OUT).
example:
	./mill run $(OUT)

# Also stops the Mill daemon, which keeps running in the background between
# builds.
clean:
	[ ! -d out ] || ./mill shutdown
	rm -rf out

.PHONY: help build test example clean
