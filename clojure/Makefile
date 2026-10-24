# Needs Java >= 25 and the Clojure CLI.

OUT ?= out.png

help:
	@echo "make build    builds it"
	@echo "make test     runs the tests"
	@echo "make example  renders the example scene to $(OUT), or another path with OUT="
	@echo "make clean    removes the build output"

# Fetches the dependencies and compiles every namespace the example uses,
# without rendering anything.
build:
	clojure -M -e "(require 'raytracer.main)"

test:
	clojure -M:test

# Renders the example scene to $(OUT).
example:
	clojure -M:run $(OUT)

clean:
	rm -rf .cpcache test/golden.actual.ppm

.PHONY: help build test example clean
