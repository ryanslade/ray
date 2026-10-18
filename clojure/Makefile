# Needs Java >= 25 and the Clojure CLI.

OUT ?= out.ppm

# Fetches the dependencies and compiles every namespace the example uses,
# without rendering anything.
build:
	clojure -M -e "(require 'raytracer.main)"

test:
	clojure -M:test

# Renders the example scene to $(OUT).
example:
	clojure -M:run $(OUT)

.PHONY: build test example
