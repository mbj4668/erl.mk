DEPS = foo

ERLMKTOP ?= $(shell cd ../../../; pwd)
export ERLMKTOP

TESTDIR ?= $(shell cd ..; pwd)
export TESTDIR

dep_foo = cp $(TESTDIR)/depvsn/foosrc

include erl.mk

erl.mk:
	cp $(ERLMKTOP)/erl.mk .
