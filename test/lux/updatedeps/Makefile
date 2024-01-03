DEPS ?= dinc

ERLMKTOP ?= $(shell cd ../../../; pwd)
export ERLMKTOP

TESTDIR ?= $(shell cd ..; pwd)
export TESTDIR

dep_dinc = cp $(TESTDIR)/dinc

# for v2
dep_include = cp $(TESTDIR)/include

include erl.mk

erl.mk:
	cp $(ERLMKTOP)/erl.mk .

