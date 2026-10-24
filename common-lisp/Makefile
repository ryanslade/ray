# Needs SBCL.

OUT ?= out.png
SBCL := sbcl --noinform --non-interactive --no-sysinit --no-userinit --load build.lisp

help:
	@echo "make build    builds it"
	@echo "make test     runs the tests"
	@echo "make example  renders the example scene to $(OUT), or another path with OUT="
	@echo "make bench    runs the benchmark, with ARGS=\"iterations threads\""
	@echo "make clean    removes the build output"

# An executable image with the compiled code already loaded.
build:
	$(SBCL) --eval '(asdf:load-system "raytracer")' \
		--eval '(save-executable "build/raytracer")'

test:
	$(SBCL) --eval '(asdf:load-system "raytracer/tests")' \
		--eval '(unless (raytracer-tests:run) (sb-ext:exit :code 1))'

# Renders the example scene to $(OUT).
example: build
	build/raytracer $(OUT)

# `make bench ARGS="iterations threads"` overrides the defaults of 20
# iterations on every core.
bench:
	$(SBCL) --eval '(asdf:load-system "raytracer/bench")' \
		--eval '(raytracer-bench:main $(ARGS))'

clean:
	rm -rf build tests/golden.actual.ppm

.PHONY: help build test example bench clean
