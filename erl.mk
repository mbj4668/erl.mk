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
### Set `DESCRIPTION` to a short description of the application
### Set `VERSION` to suppress erl.mk's version detection (git) for the .app file
### Set `SUBDIRS` to add more sub directories for the build and clean passes
### Set `ERL_OPTS` to add options to `erl` for `make shell`
### Set `ERLC_OPTS` before including erl.mk to override default options to erlc
### Add to `ERLC_OPTS` after including erl.mk to add to default options to erlc
### Set `ERLC_USE_SERVER` to `false` to avoid using erlc' compile server
### Set `ERL_MODULES` before including erl.mk to compile generated modules
### Set `EXCLUDE_ERL_MODULES` to exclude modules from the `modules` field in
###      the app file.
### Set `DEPS` to a space-separated list of run-time dependencies
### Set `LOCAL_DEPS` to a space-separated list of additional run-time
###                  dependencies (these won't be downloaded)
### Set `BUILD_DEPS` to a space-separated list of build dependencies
### Set `TEST_DEPS` to a space-separated list of test dependencies
### Set `DIALYZER_PLT` to use a specific PLT, e.g., to use a custom built PLT
### Set `DIALYZER_PLT_OPTS` to pass options to dialyzer when the PLT is built
### Set `DIALYZER_OPTS` to pass options to dialyzer
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

_PA_OPTS = $(patsubst %,-pa %/ebin,$(_DEPS_DIRS)) -pa ../$(_APP)/ebin

ERLC_OPTS ?= -Werror +warn_export_vars +warn_shadow_vars +warn_obsolete_guard
ERLC_OPTS += +debug_info -MMD -MP -MF .$(notdir $<).d -I include $(_PA_OPTS)
export ERLC_OPTS

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
	rm -rf ebin .*.d ebin/.test test/*.beam

ebin/%.beam: src/%.erl | ebin
	erlc $(ERLC_OPTS) -o ebin $<

_ERL_MODULE_LIST = $(call mkatomlist,$(filter-out $(EXCLUDE_ERL_MODULES),$(ERL_MODULES)))
_DEPS_LIST = $(call mkatomlist,$(sort $(DEPS) $(LOCAL_DEPS)))
_APP_LIST = kernel,stdlib$(if $(_DEPS_LIST),$(comma)$(_DEPS_LIST),)

ifdef DESCRIPTION
_DESCR = {description, \"$(DESCRIPTION)\"},$(newline)$(space)$(space)$(space)
endif

ifneq ($(wildcard src/$(_APP).app.src),)
$(_APP_FILE): src/$(_APP).app.src | ebin
	sed -e 's;%APP%;$(_APP);'						\
	    -e 's;%VSN%;"$(VERSION)";'						\
	    -e 's;%DESCRIPTION%;"$(DESCRIPTION)";'				\
	    -e 's;%APPLICATIONS%;$(_APP_LIST);'					\
	    -e 's;%MODULES%;$(_ERL_MODULE_LIST);' $< > $@
else
define _APP_FILE_CONTENTS
{application,$(call mkatom,$(_APP)),
  [$(_DESCR){vsn,\"$(VERSION)\"},
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

ifneq ($(MAKECMDGOALS),clean)
-include .*.d
endif

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
test-build-erl: ERLC_OPTS += -DTEST=1
test-build-erl: $(if $(wildcard ebin/.test),,erl-clean) 			\
		do-build-erl do-build-erl-tests
	$(verbose) touch ebin/.test
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
_EUNIT_TESTS = [$(call mkatomlist,$(sort $(_EUNIT_ERL_MODULES) $(ERL_MODULES)))]
endif

.PHONY: eunit
eunit: test-build-erl
	erl $(_PA_OPTS) -pa test -noshell -eval	\
	'case eunit:test($(_EUNIT_TESTS)) of ok->halt(0);error->halt(2) end'

test: eunit

.PHONY: lux lux-clean lux-build
lux: do-build-erl test-deps lux-build
	$(verbose) set -e;							\
	if [ -d test/lux ]; then						\
	  if [ -f $(DEPS_DIR)/lux/bin/lux ]; then				\
	    $(DEPS_DIR)/lux/bin/lux test/lux;					\
	  else									\
	    lux test/lux;							\
	  fi									\
	fi

lux-build:
	$(call lux_foreach,build)

test: lux

clean: lux-clean

lux-clean:
	$(call lux_foreach,clean)
	rm -rf lux_logs

define lux_foreach
set -e;										\
luxfiles=$$(if [ -d test/lux ]; then lux --mode list test/lux; fi);		\
luxdirs=$$(for d in $${luxfiles}; do echo `dirname $$d`; done | sort -u); 	\
for d in $${luxdirs}; do							\
  if [ -f $$d/Makefile ]; then							\
    $(MAKE) -C $$d $1;								\
  fi;										\
 done
endef

DIALYZER_PLT ?= .dialyzer.plt

.PHONY: dialyzer
# dialyze beam files rather than erl files to easier check generated files
dialyzer: all $(DIALYZER_PLT)
	dialyzer --plt $(DIALYZER_PLT) $(DIALYZER_OPTS)				\
	  $(_PA_OPTS) $(_BEAM_FILES)

_PLT_DEPS_DIRS = $(patsubst %,%/ebin,$(_DEPS_DIRS))

.dialyzer.plt:
	dialyzer --build_plt --output_plt $(DIALYZER_PLT) $(DIALYZER_PLT_OPTS)	\
	  --apps erts kernel stdlib $(LOCAL_DEPS) $(_PLT_DEPS_DIRS)

distclean: dialyzer-plt-clean

dialyzer-plt-clean:
	rm -f $(DIALYZER_PLT)

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
	$(MAKE) dep_patch_$(notdir $@); 					\
	if [ -f $@/rebar.config ]; then						\
	    ( cd $@ && rebar3 compile ) || exit 1;				\
	    if [ ! -d $@/ebin ]; then						\
	      ln -s _build/default/lib/$(notdir $@)/ebin $@/ebin;		\
	    fi;									\
	else									\
	    if [ -f $@/Makefile ]; then						\
	        ( cd $@ && $(MAKE) ) || exit 1;					\
	    fi;									\
	fi

dep_patch_%::
	@:

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
	$(verbose) printf '# Generated by erl.mk\n\n' > $@; \
	printf 'ERL = $$(shell readlink -f `which erl`)\n' >> $@; \
	printf 'ERL_TOP = $$(ERL:%%/bin/erl=%%)\n' >> $@; \
	printf 'OS = $$(shell uname -s)\n' >> $@; \
	printf 'DEPS_DIR = $(DEPS_DIR)\n' >> $@; \
	printf '\n' >> $@; \
	printf 'CWARNINGS ?= \\\n' >> $@; \
	printf '       -Werror \\\n' >> $@; \
        printf '       -Wall   \\\n' >> $@; \
        printf '       -Wpedantic \\\n' >> $@; \
        printf '       -Wsign-compare \\\n' >> $@; \
        printf '       -Wcast-align \\\n' >> $@; \
        printf '       -Wstrict-prototypes\n' >> $@; \
        printf 'ifneq ($$(DEBUG),)\n' >> $@; \
        printf '  CEXTRA_FLAGS = -g -ggdb\n' >> $@; \
        printf 'else\n' >> $@; \
        printf '  CEXTRA_FLAGS = -O2\n' >> $@; \
        printf 'endif\n' >> $@; \
	printf '\n' >> $@; \
	printf 'CFLAGS ?= -std=c99 $$(CWARNINGS) $$(CEXTRA_FLAGS)\n' >> $@; \
	printf 'CFLAGS += -MMD -MP -MF .$$<.d -I$$(ERL_TOP)/usr/include\n' >>$@;\
	printf '\n' >> $@; \
	printf 'ifeq ($$(OS), Linux)\n' >> $@; \
	printf '  LDFLAGS_NIF = -shared\n' >> $@; \
	printf '  CFLAGS += -fPIC\n' >> $@; \
	printf 'else ifeq ($$(OS), Darwin)\n' >> $@; \
	printf '  LDFLAGS_NIF = -bundle -undefined dynamic_lookup\n' >> $@; \
	printf '  CFLAGS += -fPIC -fno-common\n' >> $@; \
	printf 'endif\n' >> $@; \
	printf '\n' >> $@; \
	printf 'ifneq ($$(MAKECMDGOALS),clean)\n' >> $@; \
	printf -- '-include .*.d\n' >> $@; \
	printf 'endif\n' >> $@

### Helpers

# Used to be:
#   $(shell erl -noshell -eval 'io:write(list_to_atom("$1")),halt()')
# which is 100% correct, but slow.
# Current function is not perfect, but good enough.
define mkatom
$(shell echo $1 | awk "/[a-z]([a-z][A-Z][0-9]_@)*/ {print $$1; next} \
                       {print \"'\" $$1 \"'\"}")
endef

define mkatomlist
$(subst $(space),$(comma),$(foreach m,$1,$(call mkatom,$(m))))
endef
