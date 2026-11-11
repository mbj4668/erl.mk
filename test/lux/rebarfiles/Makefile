
ERLMKTOP ?= $(shell cd ../../../; pwd)
export ERLMKTOP

TESTDIR ?= $(shell cd ..; pwd)
export TESTDIR

DEPS = foo bar

FOO_VSN ?= 1.0.0
dep_foo = hex $(FOO_VSN)
dep_bar = git https://example.com/bar.git v1

include erl.mk

erl.mk:
	cp $(ERLMKTOP)/erl.mk .

clean: my-clean

my-clean:
	rm -f rebar.config src/rebarfiles.app.src.script
