DEPS = erlfmt eclip idna

dep_erlfmt = git https://github.com/WhatsApp/erlfmt.git v1.6.0
dep_eclip = git https://github.com/mbj4668/eclip.git
dep_idna = hex 6.1.1

ERLMKTOP ?= $(shell cd ../../../; pwd)
export ERLMKTOP

include erl.mk

erl.mk:
	cp $(ERLMKTOP)/erl.mk .

dep_patch_eclip::
	touch $(DEPS_DIR)/eclip/MY_PATCH

dep_build_erlfmt::
	( cd $(DEPS_DIR)/erlfmt && make release && $(call built_dep,erlfmt) )
