# Needs Java >= 17 to run Gradle, which downloads Java 25 if it isn't
# installed.

OUT ?= out.ppm

build:
	./gradlew assemble

test:
	./gradlew test

# Renders the example scene to $(OUT).
example:
	./gradlew run --args=$(OUT)

.PHONY: build test example
