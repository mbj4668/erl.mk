
ERLMKTOP ?= $(shell cd ../../../; pwd)
export ERLMKTOP

TESTDIR ?= $(shell cd ..; pwd)
export TESTDIR

include erl.mk

erl.mk:
	cp $(ERLMKTOP)/erl.mk .

print-erl-libs:
	@echo "ERL_LIBS=[$(ERL_LIBS)]"
