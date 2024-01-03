SUBDIRS = sub1 sub2

ERLMKTOP ?= $(shell cd ../../../; pwd)
export ERLMKTOP

include erl.mk

erl.mk:
	cp $(ERLMKTOP)/erl.mk .

