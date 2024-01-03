DEPS = include

ERLMKTOP ?= $(shell cd ../../../; pwd)
export ERLMKTOP

TESTDIR ?= $(shell cd ..; pwd)
export TESTDIR

dep_include = cp $(TESTDIR)/include

include erl.mk

erl.mk:
	cp $(ERLMKTOP)/erl.mk .

