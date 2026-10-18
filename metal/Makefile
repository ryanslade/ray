# Needs macOS 15 and Swift 6.

OUT ?= out.ppm

# The Command Line Tools include Swift Testing, but `swift test` only finds it
# by itself with Xcode.
ifeq ($(shell xcode-select -p 2>/dev/null),/Library/Developer/CommandLineTools)
CLT := /Library/Developer/CommandLineTools/Library/Developer
TEST_FLAGS := -Xswiftc -F$(CLT)/Frameworks -Xlinker -rpath -Xlinker $(CLT)/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT)/usr/lib
endif

build:
	swift build -c release

test:
	swift test $(TEST_FLAGS)

# Renders the example scene to $(OUT).
example:
	swift run -c release raytracer $(OUT)

.PHONY: build test example
