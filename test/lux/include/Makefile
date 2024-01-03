DEPS = dinc

ERLMKTOP ?= $(shell cd ../../../; pwd)
export ERLMKTOP

TESTDIR ?= $(shell cd ..; pwd)
export TESTDIR

dep_dinc = cp $(TESTDIR)/dinc

include erl.mk

erl.mk:
	cp $(ERLMKTOP)/erl.mk .

