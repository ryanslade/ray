# Needs a C11 compiler with pthreads, such as GCC or Clang.

CFLAGS ?= -O3 -flto
# A fused multiply-add rounds once rather than twice, so contraction (on by
# default in Clang, and in GCC outside strict ISO modes) is turned off to keep
# the floating point operations the same as the Rust version's.
RT_CFLAGS := -std=c11 -Wall -Wextra -Wpedantic -Wshadow -ffp-contract=off -pthread
CPPFLAGS += -D_POSIX_C_SOURCE=200809L -Isrc -Itests
LDLIBS += -lm

# `make test SANITIZE=address,undefined` builds with those sanitizers, in a
# separate build directory.
comma := ,
ifdef SANITIZE
BUILD := build/$(subst $(comma),-,$(SANITIZE))
RT_CFLAGS += -fsanitize=$(SANITIZE) -fno-omit-frame-pointer -g
else
BUILD := build/release
endif

OUT ?= out.ppm

LIB_OBJS := $(patsubst %.c,$(BUILD)/obj/%.o,$(filter-out src/main.c,$(wildcard src/*.c)))
SCENE_OBJ := $(BUILD)/obj/tests/scene.o
PROGRAMS := $(addprefix $(BUILD)/,raytracer test_unit test_render bench)
SOURCES := $(wildcard src/*.[ch] tests/*.[ch] bench/*.[ch])

all: build

build: $(BUILD)/raytracer

$(BUILD)/raytracer: $(BUILD)/obj/src/main.o $(LIB_OBJS)
$(BUILD)/test_unit: $(BUILD)/obj/tests/test_unit.o $(LIB_OBJS)
$(BUILD)/test_render: $(BUILD)/obj/tests/test_render.o $(SCENE_OBJ) $(LIB_OBJS)
$(BUILD)/bench: $(BUILD)/obj/bench/bench.o $(SCENE_OBJ) $(LIB_OBJS)

$(PROGRAMS):
	$(CC) $(RT_CFLAGS) $(CFLAGS) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(BUILD)/obj/%.o: %.c
	@mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(RT_CFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

# Renders the example scene to $(OUT).
example: $(BUILD)/raytracer
	$(BUILD)/raytracer $(OUT)

test: $(BUILD)/test_unit $(BUILD)/test_render
	$(BUILD)/test_unit
	$(BUILD)/test_render

# `make bench ARGS="iterations threads"` overrides the defaults of 20
# iterations on every core.
bench: $(BUILD)/bench
	$(BUILD)/bench $(ARGS)

format:
	clang-format -i $(SOURCES)

format-check:
	clang-format --dry-run --Werror $(SOURCES)

clean:
	rm -rf build tests/golden.actual.ppm

.PHONY: all build example test bench format format-check clean

-include $(patsubst %.o,%.d,$(LIB_OBJS) $(SCENE_OBJ) $(addprefix $(BUILD)/obj/,src/main.o tests/test_unit.o tests/test_render.o bench/bench.o))
