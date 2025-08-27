
ERLMKTOP ?= $(shell cd ../../../; pwd)
export ERLMKTOP

TESTDIR ?= $(shell cd ..; pwd)
export TESTDIR

include erl.mk

erl.mk:
	cp $(ERLMKTOP)/erl.mk .

clean: my-clean

my-clean:
	rm -f src/b-b.erl
