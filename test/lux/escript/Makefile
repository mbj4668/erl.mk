
ERLMKTOP ?= $(shell cd ../../../; pwd)
export ERLMKTOP

TESTDIR ?= $(shell cd ..; pwd)
export TESTDIR

ESCRIPT_FILE = bin/foo
ESCRIPT_MODULE = a

include erl.mk

all: escript

erl.mk:
	cp $(ERLMKTOP)/erl.mk .

clean: my-clean

my-clean:
	rm -rf bin
