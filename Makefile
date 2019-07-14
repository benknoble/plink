SHELL = /bin/sh

.SUFFIXES:

PLINK = Plink.pm

TEST_DIR = t
TEST = $(TEST_DIR)/test.plink
TEST_EXPECTED = $(TEST_DIR)/expected.mk
TEST_OUTPUT = $(TEST_DIR)/Makefile

all: test

test: $(TEST_OUTPUT)

$(TEST_OUTPUT): $(PLINK) $(TEST) $(TEST_EXPECTED)
	cd $(TEST_DIR) && ../$(PLINK) $$( basename $(TEST) )
	diff -qswB $(TEST_EXPECTED) $(TEST_OUTPUT)

view_test: $(TEST_OUTPUT)
	vimdiff $(TEST_EXPECTED) $(TEST_OUTPUT)

clean:
	-$(RM) $(TEST_OUTPUT)
