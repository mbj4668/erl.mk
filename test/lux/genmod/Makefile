
ERLMKTOP ?= $(shell cd ../../../; pwd)
export ERLMKTOP

TESTDIR ?= $(shell cd ..; pwd)
export TESTDIR

GENERATED_ERL_MODULES = g

include erl.mk

erl.mk:
	cp $(ERLMKTOP)/erl.mk .

src/g.erl: g.erl.in
	cp $< $@
