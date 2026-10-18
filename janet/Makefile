# Needs Janet >= 1.41.

OUT ?= out.ppm

# There's nothing to build, so this compiles every module without rendering
# anything. Unlike `janet -k`, importing exits with an error status if a
# module doesn't compile.
build:
	janet -e '(import ./main) (import ./bench)'

# The same as jpm test, without needing jpm.
test:
	for t in test/*.janet; do janet "$$t" || exit 1; done

# Renders the example scene to $(OUT).
example:
	janet main.janet $(OUT)

.PHONY: build test example
