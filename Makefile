CC = gcc
CPPFLAGS += -Iinclude
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic
PROGRAMS := $(patsubst src/%.c,build/%,$(wildcard src/prog-*.c))
TEST_BIN := build/test_tlb

.PHONY: all test clean
all: $(PROGRAMS)

build:
	mkdir -p $@

build/%: src/%.c include/cache.h include/tlb.h | build
	$(CC) $(CPPFLAGS) $(CFLAGS) $< $(LDFLAGS) $(LDLIBS) -o $@

$(TEST_BIN): tests/test_tlb.c include/tlb.h | build
	$(CC) $(CPPFLAGS) $(CFLAGS) $< $(LDFLAGS) $(LDLIBS) -o $@

test: $(TEST_BIN)
	./$(TEST_BIN)

clean:
	$(RM) $(PROGRAMS) $(TEST_BIN) res-*
