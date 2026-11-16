CC = gcc
CPPFLAGS += -Iinclude
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic
PROGRAMS := $(patsubst src/%.c,build/%,$(wildcard src/prog-*.c))

.PHONY: all clean
all: $(PROGRAMS)

build:
	mkdir -p $@

build/%: src/%.c include/cache.h include/tlb.h | build
	$(CC) $(CPPFLAGS) $(CFLAGS) $< $(LDFLAGS) $(LDLIBS) -o $@

clean:
	$(RM) $(PROGRAMS)
