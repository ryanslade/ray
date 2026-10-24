# Needs Java >= 17 to run Gradle, which downloads Java 25 if it isn't
# installed.

OUT ?= out.png

help:
	@echo "make build    builds it"
	@echo "make test     runs the tests"
	@echo "make example  renders the example scene to $(OUT), or another path with OUT="
	@echo "make clean    removes the build output"

build:
	./gradlew assemble

test:
	./gradlew test

# Renders the example scene to $(OUT).
example:
	./gradlew run --args=$(OUT)

clean:
	./gradlew clean

.PHONY: help build test example clean
