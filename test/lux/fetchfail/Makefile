DEPS = foo $(EXTRA_DEPS)

ERLMKTOP ?= $(shell cd ../../../; pwd)
export ERLMKTOP

TESTDIR ?= $(shell cd ..; pwd)
export TESTDIR

dep_foo = cp $(TESTDIR)/fetchfail/foosrc
dep_nocp = cp $(TESTDIR)/fetchfail/nosuchdir
dep_nogit = git $(TESTDIR)/fetchfail/nosuchrepo

include erl.mk

erl.mk:
	cp $(ERLMKTOP)/erl.mk .

ifdef FAIL_PATCH
dep_patch_foo::
	false
endif
