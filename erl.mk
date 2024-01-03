### API - i.e., targets defined to be used by user
### ==============================================
###   all         - build everything
###   test        - run tests, if defined
###   dialyzer    - run dialyzer
###   eunit       - run eunit tests
###   lux         - run lux tests
###   shell       - start an erlang shell with correct paths
###   clean       - clean application
###   distclean   - clean application and dependencies
###
###   c_src.mk    - generate `c_src.mk` with useful variables
###
### Customization - variables
### =========================
### Set `SUBDIRS` to add more sub directories for the build and clean passes
### Set `ERL_OPTS` to add options to `erl` for `make shell`
### Set `ERLC_OPTS` before including erl.mk to override default options to erlc
### Add to `ERLC_OPTS` after including erl.mk to add to default options to erlc
### Set `DIALYZER_OPTS` to pass options to dialyzer
### Set `VERSION` to suppress erl.mk's version detection (git) for the .app file
### Set `ERLC_USE_SERVER` to `false` to avoid using erlc' compile server
### Set `ERL_MODULES` before including erl.mk to compile generated modules
### Set `EXCLUDE_ERL_MODULES` to exclude modules from the `modules` field in
###      the app file.
### Set `DEPS` to a space-separated list of run-time dependencies
### Set `LOCAL_DEPS` to a space-separated list of additional run-time
###                  dependencies (these won't be downloaded)
### Set `BUILD_DEPS` to a space-separated list of build dependencies
### Set `TEST_DEPS` to a space-separated list of test dependencies
###
### Customization - targets
### =======================
### Add to `all:` to build more
### Add to `clean:` and `distclean` to clean more
### Add to `test:` to test more

all: deps

.PHONY: all clean
all clean:
	$(verbose) for d in $(SUBDIRS) ; do					\
	  if [ -f $$d/Makefile ]; then						\
	    $(MAKE) -C $$d $@ || exit 1;					\
	  fi;									\
	done

.PHONY: distclean
distclean: clean deps-clean

### Useful variables

comma := ,
empty :=
space := $(empty) $(empty)
define newline


endef

### Verbosity

V ?= 0

verbose_0 = @
verbose_2 = set -x;
verbose = $(verbose_$(V))

### Erlang

_APP = $(shell basename `pwd`)
VERSION ?= $(shell git describe --always --tags 2> /dev/null || echo 0.1)

_ERL_SOURCES = $(wildcard src/*.erl)
ERL_MODULES += $(_ERL_SOURCES:src/%.erl=%)
_BEAM_FILES = $(ERL_MODULES:%=ebin/%.beam)
_APP_FILE = ebin/$(_APP).app

_PA_OPTS = $(patsubst %,-pa %/ebin,$(_DEPS_DIRS)) -pa ebin

ERLC_OPTS ?= -Werror +warn_export_vars +warn_shadow_vars +warn_obsolete_guard \
	     +debug_info
ERLC_OPTS += -MMD -MP -MF .$(notdir $<).d -I include $(_PA_OPTS)

ERLC_USE_SERVER ?= true
export ERLC_USE_SERVER

all: build-erl

.PHONY: build-erl
build-erl: $(if $(wildcard ebin/.test),erl-clean,) do-build-erl

.PHONY: do-build-erl
do-build-erl: $(_APP_FILE) $(_BEAM_FILES)

clean: erl-clean

.PHONY: erl-clean
erl-clean:
	rm -rf ebin .*.d ebin/.test

ebin/%.beam: src/%.erl | ebin
	erlc $(ERLC_OPTS) -o ebin $<

_ERL_MODULE_LIST = $(subst $(space),$(comma),$(filter-out \
			$(EXCLUDE_ERL_MODULES),$(ERL_MODULES)))
_DEPS_LIST = $(subst $(space),$(comma),$(sort $(DEPS) $(LOCAL_DEPS)))
_APP_LIST = kernel,stdlib$(if $(_DEPS_LIST),$(comma)$(_DEPS_LIST),)

ifneq ($(wildcard src/$(_APP).app.src),)
$(_APP_FILE): src/$(_APP).app.src | ebin
	sed -e 's;%APP%;$(_APP);'						\
	    -e 's;%VSN%;"$(VERSION)";'						\
	    -e 's;%APPLICATIONS%;$(_APP_LIST);'					\
	    -e 's;%MODULES%;$(_ERL_MODULE_LIST);' $< > $@
else
define _APP_FILE_CONTENTS
{application,'$(_APP)',
  [{vsn,\"$(VERSION)\"},
   {modules,[$(_ERL_MODULE_LIST)]},
   {registered,[]},
   {env,[]},
   {applications,[$(_APP_LIST)]}]}.
endef
$(_APP_FILE): | ebin
	printf "$(subst $(newline),\n,$(_APP_FILE_CONTENTS))\n" > $@
endif

ebin:
	mkdir $@

-include .*.d

### Tests

.PHONY: test
test: test-deps
	$(verbose) if [ -f test/Makefile ]; then				\
	  $(MAKE) -C test;							\
	fi;									\

_EUNIT_ERL_SOURCES = $(wildcard test/*_tests.erl)
_EUNIT_ERL_MODULES = $(_EUNIT_ERL_SOURCES:test/%.erl=%)
_EUNIT_BEAM_FILES = $(_EUNIT_ERL_MODULES:%=test/%.beam)

.PHONY: test-build-erl
test-build-erl: ERLC_OPTS += -DTEST=1 +debug_info
test-build-erl: $(if $(wildcard ebin/.test),,erl-clean) do-build-erl do-build-erl-tests
	$(verbose) touch ebin/.test

.PHONY: do-build-erl-tests
do-build-erl-tests: $(_EUNIT_BEAM_FILES)

test/%.beam: test/%.erl
	erlc $(ERLC_OPTS) -o test $<

ifdef t
ifeq (,$(findstring :,$(t)))
_EUNIT_TESTS = [$(t)]
else
_EUNIT_TESTS = fun $(t)/0
endif
else
_EUNIT_TESTS = [$(subst $(space),$(comma),$(sort $(_EUNIT_ERL_MODULES) $(_ERL_MODULES)))]
endif

.PHONY: eunit
eunit: test-build-erl
	erl $(_PA_OPTS) -pa test -noshell -eval	\
	'case eunit:test($(_EUNIT_TESTS)) of ok->halt(0);error->halt(2) end'

test: eunit

.PHONY: lux
lux: do-build-erl test-deps
	$(verbose) set -e;							\
	if [ -d test/lux ]; then						\
	  if [ -f $(DEPS_DIR)/lux/bin/lux ]; then				\
	    $(DEPS_DIR)/lux/bin/lux test/lux;					\
	  else									\
	    lux test/lux;							\
	  fi									\
	fi

test: lux

clean: lux-clean

lux-clean:
	rm -rf lux_logs

.PHONY: dialyzer
dialyzer: all
	dialyzer $(DIALYZER_OPTS) $(_PA_OPTS) --src src/*.erl

.PHONY: shell
shell:
	erl $(ERL_OPTS) $(_PA_OPTS)

### External dependency handling

# export DEPS_DIR so that recursive dependencies are fetched to DEPS_DIR
DEPS_DIR ?= $(CURDIR)/deps
export DEPS_DIR

# automatically add lux as a test dependency if needed
ifneq ($(wildcard test/lux),) # are there any lux tests?
ifeq ($(shell which lux),)    # is lux present in the PATH?
_ALL_TEST_DEPS = $(sort $(TEST_DEPS) lux) # add lux if not present in TEST_DEPS
ifndef dep_lux
dep_lux = git https://github.com/hawk/lux
endif
endif
endif
_ALL_TEST_DEPS ?= $(TEST_DEPS)

_DEPS_DIRS = $(patsubst %,$(DEPS_DIR)/%,$(DEPS))
_BUILD_DEPS_DIRS = $(patsubst %,$(DEPS_DIR)/%,$(BUILD_DEPS))
_TEST_DEPS_DIRS = $(patsubst %,$(DEPS_DIR)/%,$(_ALL_TEST_DEPS))

.PHONY: deps
deps: $(_DEPS_DIRS) $(_BUILD_DEPS_DIRS)

.PHONY: test-deps
test-deps: $(_TEST_DEPS_DIRS)

# A dependency is not rebuilt once it has been installed.
# To force a rebuild, first remove `deps/NAME`, then run `make`.
$(DEPS_DIR)/%:
	mkdir -p $(DEPS_DIR)
	$(call dep_fetch_$(word 1, $(dep_$(notdir $@))),$(notdir $@))
	if [ -f $@/configure.ac -o -f $@/configure.in ]; then			\
	    ( cd $@ && autoreconf -if )						\
	fi;									\
	if [ -f $@/configure ]; then						\
	    ( cd $@ && ./configure)						\
	fi;									\
	if [ -f $@/Makefile ]; then						\
	    ( cd $@ && $(MAKE) ) || exit 1;					\
	elif [ -f $@/rebar.config ]; then					\
	    ( cd $@ && rebar3 compile ) || exit 1;				\
	    if [ ! -d $@/ebin ]; then						\
	      ln -s _build/default/lib/$(notdir $@)/ebin $@/ebin;		\
	    fi;									\
	fi

.PHONY: deps-clean
deps-clean:
	rm -rf $(DEPS_DIR)

define dep_fetch_git
	git clone -q -n $(word 2,$(dep_$1)) $(DEPS_DIR)/$1;			\
	(cd $(DEPS_DIR)/$(1) &&							\
	  git checkout -q $(if $(word 3,$(dep_$1)),				\
	                       $(word 3,$(dep_$1)),				\
	                       HEAD));
endef

define dep_fetch_hex
	mkdir $(DEPS_DIR)/$1;							\
	curl -s https://repo.hex.pm/tarballs/$1-$(word 2,$(dep_$1)).tar |	\
	tar -xO contents.tar.gz | tar -C $(DEPS_DIR)/$1 -xzm;
endef

define dep_fetch_ln
	ln -s $(abspath $(word 2,$(dep_$1))) $(DEPS_DIR)/$1;
endef

define dep_fetch_cp
	cp -R $(abspath $(word 2,$(dep_$1))) $(DEPS_DIR)/$1;
endef

### C source

SUBDIRS	+= c_src

c_src.mk:
	@printf '# Generated by erl.mk' > $@; \
	printf 'ERL=$$(shell readlink -f `which erl`)\n' >> $@; \
	printf 'ERL_TOP=$$(ERL:%%/bin/erl=%%)\n' >> $@; \
	printf 'OS=$$(shell uname -s)\n' >> $@; \
	printf 'CFLAGS=-MMD -MP -MF .$$<.d -I$$(ERL_TOP)/usr/include\n' >> $@
