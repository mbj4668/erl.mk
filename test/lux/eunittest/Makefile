
ERLMKTOP ?= $(shell cd ../../../; pwd)
export ERLMKTOP

TESTDIR ?= $(shell cd ..; pwd)
export TESTDIR

EUNIT_OPTS = verbose

include erl.mk

erl.mk:
	cp $(ERLMKTOP)/erl.mk .

