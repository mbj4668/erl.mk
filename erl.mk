### See https://github.com/mbj4668/erl.mk for documentation
###
### API - i.e., targets defined to be used by user
### ==============================================
###   all         - build everything including dependencies
###   test        - run tests, if defined
###   dialyzer    - run dialyzer
###   eunit       - run eunit tests
###   lux         - run lux tests
###   shell       - start an erlang shell with correct paths
###   clean       - clean application
###   test-clean  - clean tests
###   distclean   - clean application, tests and remove dependencies
###   fetch-deps  - fetch dependencies
###   build-deps  - build dependencies
###
###   c_src.mk    - generate `c_src.mk` with useful variables
###   rebar-files - generate files for compatibility with rebar

.DELETE_ON_ERROR:

.PHONY: all clean distclean
all: deps

clean:

distclean: clean

### Handle sub directories

SUBDIRS	+= $(patsubst %/Makefile,%,$(wildcard c_src/Makefile))

all clean: _subdirs
all: _SUBDIR_TARGET=all
clean: _SUBDIR_TARGET=clean

.PHONY: _subdirs $(SUBDIRS)
_subdirs: $(SUBDIRS)

$(SUBDIRS):
	$(verbose) $(MAKE) -C $@ $(_SUBDIR_TARGET)

### Useful variables

comma := ,
empty :=
space := $(empty) $(empty)
define newline


endef

# export ERL_MK_FILENAME so that recursive dependencies can use the same file
ERL_MK_FILENAME := $(realpath $(lastword $(MAKEFILE_LIST)))
export ERL_MK_FILENAME

### Verbosity

V ?= 0

verbose_0 = @
verbose_2 = set -x;
verbose = $(verbose_$(V))

gen_verbose_0 = @echo " GEN   " $@;
gen_verbose_2 = set -x;
gen_verbose = $(gen_verbose_$(V))

erlc_verbose_0 = @echo " ERLC  " $@;
erlc_verbose_2 = set -x;
erlc_verbose = $(erlc_verbose_$(V))

app_verbose_0 = @echo " APP   " $@;
app_verbose_2 = set -x;
app_verbose = $(app_verbose_$(V))

fetch_verbose_0 = @echo " FETCH " $(notdir $@) "($(call get_dep_version,$(notdir $@)))";
fetch_verbose_2 = set -x;
fetch_verbose = $(fetch_verbose_$(V))

dep_verbose_0 = @echo " DEP   " $(notdir $<);
dep_verbose_2 = set -x;
dep_verbose = $(dep_verbose_$(V))

### Erlang

_APP = $(shell basename `pwd`)
VERSION ?= $(shell git describe --always --tags 2> /dev/null || echo 0.1)
APP_ENV ?= []

_ERL_SOURCES = $(wildcard src/*.erl)
_ERL_MODULES = $(sort $(GENERATED_ERL_MODULES) $(_ERL_SOURCES:src/%.erl=%))
_BEAM_FILES = $(_ERL_MODULES:%=ebin/%.beam)
_APP_FILE = ebin/$(_APP).app

_PA_OPTS = $(patsubst %,-pa %/ebin,$(_DEPS_DIRS)) -pa ../$(_APP)/ebin

ERLC_OPTS ?= -Werror +warn_export_vars +warn_shadow_vars +warn_obsolete_guard
ERLC_OPTS += +debug_info -MMD -MP -MF .$(notdir $<).d -I include $(_PA_OPTS)

ERLC_USE_SERVER ?= true
export ERLC_USE_SERVER

all: build-erl

.PHONY: build-erl
build-erl: $(if $(wildcard ebin/.test),erl-clean,) do-build-erl

.PHONY: do-build-erl
do-build-erl:

ifneq ($(_ERL_SOURCES),)
do-build-erl: $(_APP_FILE) $(_BEAM_FILES)
endif

clean: erl-clean ebin-clean

.PHONY: erl-clean
erl-clean:
	$(verbose) rm -rf ebin/.test .*.d ebin/*.beam ebin/*.app test/*.beam .erl.mk.* \
	    $(GENERATED_ERL_MODULES)

ebin-clean:
	$(verbose) rm -rf ebin

ebin/%.beam: src/%.erl | ebin
	$(erlc_verbose) erlc $(filter-out $(REMOVE_ERLC_OPTS),$(ERLC_OPTS)) -o ebin $<

_ERL_MODULE_LIST = $(call mkatomlist,$(filter-out $(EXCLUDE_ERL_MODULES),$(_ERL_MODULES)))
_DEPS_LIST = $(call mkatomlist,$(sort $(DEPS) $(LOCAL_DEPS)))
_APP_LIST = kernel,stdlib$(if $(_DEPS_LIST),$(comma)$(_DEPS_LIST),)

ifeq ($(ERL_LIBS),)
	ERL_LIBS = $(DEPS_DIR)
else
	ERL_LIBS := $(ERL_LIBS):$(DEPS_DIR)
endif
export ERL_LIBS

ifneq ($(wildcard src/$(_APP)_app.erl),)
_APP_MOD = {mod,{$(_APP)_app,[]}},$(newline)$(space)$(space)$(space)
endif

APP_SRC_SUFFIX ?= .src
ifneq ($(wildcard src/$(_APP).app$(APP_SRC_SUFFIX)),)
$(_APP_FILE): src/$(_APP).app$(APP_SRC_SUFFIX) .erl.mk.app | ebin
	$(app_verbose) sed -e 's;%APP%;$(_APP);'						\
	    -e 's;%VSN%;"$(VERSION)";'								\
	    -e 's;%DESCRIPTION%;"$(subst ",\\\",$(DESCRIPTION))";'				\
	    -e 's;%APPLICATIONS%;$(_APP_LIST);'							\
	    -e "s;%APP_ENV%;$(subst ",\",$(APP_ENV));"						\
	    -e "s;%MODULES%;$(_ERL_MODULE_LIST);" $< > $@
else
define _APP_FILE_CONTENTS
{application,$(call mkatom,$(_APP)),
  [{description,\"$(subst ",\\\",$(DESCRIPTION))\"},
   {vsn,\"$(VERSION)\"},
   {modules,[$(_ERL_MODULE_LIST)]},
   $(_APP_MOD){registered,[]},
   {env, $(subst ",\",$(APP_ENV))},
   {applications,[$(_APP_LIST)]}]}.
endef
# "
$(_APP_FILE): .erl.mk.app | ebin
	$(app_verbose) printf "$(subst $(newline),\n,$(_APP_FILE_CONTENTS))\n" > $@
endif

define _APP_FILE_DATA
$(subst $(newline),,$(subst ',,$(_APP)$(DESCRIPTION)$(VERSION)$(_ERL_MODULE_LIST)$(_APP_MOD)$(APP_ENV)$(_APP_LIST)))
endef
#'
.erl.mk.app: FORCE
	@if ! (echo '$(_APP_FILE_DATA)' | cmp -s - $@); then echo '$(_APP_FILE_DATA)' > $@; fi

FORCE:

ebin:
	$(gen_verbose) mkdir $@

ifneq ($(MAKECMDGOALS),clean)
-include .*.d
endif

### Tests

.PHONY: test
test: test-deps
	$(verbose) if [ -f test/Makefile ]; then						\
	  $(MAKE) -C test;									\
	fi;											\

distclean: test-clean

.PHONY: test-clean
test-clean: do-test-clean

.PHONY: do-test-clean
do-test-clean:
	$(verbose) if [ -f test/Makefile ]; then						\
	  $(MAKE) -C test clean;								\
	fi;											\

_EUNIT_ERL_SOURCES = $(wildcard test/*_tests.erl)
_EUNIT_ERL_MODULES = $(_EUNIT_ERL_SOURCES:test/%.erl=%)
_EUNIT_BEAM_FILES = $(_EUNIT_ERL_MODULES:%=test/%.beam)

.PHONY: test-build-erl
test-build-erl: ERLC_OPTS += -DTEST=1
test-build-erl: REMOVE_ERLC_OPTS += -Werror
test-build-erl: $(if $(wildcard ebin/.test),,erl-clean) do-build-erl do-build-erl-tests
	$(verbose) touch ebin/.test

.PHONY: do-build-erl-tests
do-build-erl-tests: $(_EUNIT_BEAM_FILES)

test/%.beam: test/%.erl
	$(erlc_verbose) erlc $(filter-out $(REMOVE_ERLC_OPTS),$(ERLC_OPTS)) -o test $<

ifdef t
ifeq (,$(findstring :,$(t)))
_EUNIT_TESTS = [$(t)]
else
_EUNIT_TESTS = fun $(t)/0
endif
else
_EUNIT_EXTRA_MODULES = $(filter-out $(patsubst %,%_tests,$(_ERL_MODULES)),$(_EUNIT_ERL_MODULES))
_EUNIT_TESTS = [$(call mkatomlist,$(_ERL_MODULES) $(_EUNIT_EXTRA_MODULES))]
endif

.PHONY: eunit
eunit: test-deps test-build-erl
	$(verbose) erl $(_PA_OPTS) -pa test -noshell $(EUNIT_ERL_OPTS) -eval			\
	"case eunit:test($(_EUNIT_TESTS), [$(EUNIT_OPTS)]) of ok->halt(0);error->halt(2) end"

test: eunit

.PHONY: lux lux-build lux-clean
lux: test-deps do-build-erl lux-build
	$(verbose) set -e;									\
	if [ -d test/lux ]; then								\
	  if [ -f $(DEPS_DIR)/lux/bin/lux ]; then						\
	    $(DEPS_DIR)/lux/bin/lux $(LUX_OPTS) test/lux;					\
	  else											\
	    lux $(LUX_OPTS) test/lux;								\
	  fi											\
	fi

lux-build:
	$(call lux_foreach,build)

test: lux

test-clean: lux-clean

lux-clean:
	$(call lux_foreach,clean)
	$(verbose) rm -rf lux_logs

define lux_foreach
set -e;												\
lux=$$(which lux || echo $(DEPS_DIR)/lux/bin/lux);						\
luxfiles=$$(if [ -d test/lux -a -x "$${lux}" ]; 						\
	    then $${lux} --mode list test/lux; fi);						\
luxdirs=$$(for d in $${luxfiles}; do echo `dirname $${d}`; done | sort -u); 			\
for d in $${luxdirs}; do									\
  if [ -f $${d}/Makefile ]; then								\
    $(MAKE) -C $${d} $1;									\
  fi;												\
 done
endef

DIALYZER_PLT ?= .dialyzer.plt

.PHONY: dialyzer dialyzer-plt-clean
# dialyze beam files rather than erl files to easier check generated files
dialyzer: all $(DIALYZER_PLT)
	$(verbose) dialyzer --plt $(DIALYZER_PLT) $(DIALYZER_OPTS)				\
	  $(_PA_OPTS) $(_BEAM_FILES) ||								\
	if [ $$? -eq 1 ]; then exit 1; fi

_PLT_DEPS_DIRS = $(patsubst %,%/ebin,$(_DEPS_DIRS))

$(DIALYZER_PLT):
	$(gen_verbose) dialyzer --build_plt --output_plt $@ $(DIALYZER_PLT_OPTS)		\
	  --apps erts kernel stdlib $(PLT_APPS) $(LOCAL_DEPS) $(_PLT_DEPS_DIRS) 		\
	|| if [ $$? -eq 1 ]; then exit 1; fi

distclean: dialyzer-plt-clean

dialyzer-plt-clean:
	rm -f $(DIALYZER_PLT)

.PHONY: shell
shell:
	erl $(_PA_OPTS)

### External dependency handling

# export DEPS_DIR so that recursive dependencies are fetched to DEPS_DIR
DEPS_DIR ?= $(CURDIR)/deps
export DEPS_DIR

# automatically add lux as a test dependency if needed
ifneq ($(wildcard test/lux),) # are there any lux tests?
ifeq ($(shell which lux),) # is lux present in the PATH or set properly?
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

_DEPS_BUILT = $(patsubst %,$(DEPS_DIR)/%/.dep_built,$(DEPS))
_BUILD_DEPS_BUILT = $(patsubst %,$(DEPS_DIR)/%/.dep_built,$(BUILD_DEPS))
_TEST_DEPS_BUILT = $(patsubst %,$(DEPS_DIR)/%/.dep_built,$(_ALL_TEST_DEPS))

.PHONY: deps fetch-deps build-deps
deps: fetch-deps build-deps
fetch-deps: $(_DEPS_DIRS) $(_BUILD_DEPS_DIRS)
build-deps: $(_DEPS_BUILT) $(_BUILD_DEPS_BUILT)

.PHONY: test-deps fetch-test-deps build-test-deps
test-deps: fetch-test-deps build-test-deps
fetch-test-deps: $(_TEST_DEPS_DIRS)
build-test-deps: $(_TEST_DEPS_BUILT)

$(DEPS_DIR)/%/.dep_built: $(DEPS_DIR)/%
	$(dep_verbose) $(MAKE) --no-print-directory dep_build_$(notdir $<) || exit 1;		\
	if [ -f $@ ]; then									\
	    :;											\
	elif [ \( -f $</rebar.config -o -f $</rebar.config.script \) -a				\
	       ! \( -f $</erlang.mk -a -f $</Makefile \) -a					\
	       -z "$$(head -1 $</rebar.config 2>/dev/null | grep erl.mk)" ]; then		\
	    if [ ! -h $</ebin ]; then								\
	      ( cd $< && rebar3 compile ) || exit 1;						\
	    fi;											\
	    if [ ! -d $</ebin ]; then								\
	      ln -s $</_build/default/lib/$(notdir $<)/ebin $</ebin;				\
	    fi;											\
	    if [ ! -d $</priv -a -d $</_build/default/lib/$(notdir $<)/priv ]; then		\
	      ln -s $</_build/default/lib/$(notdir $<)/priv $</priv;				\
	    fi;											\
	    for e in $</_build/default/lib/*; do				 		\
	      edep=`basename $${e}`;								\
	      if [ -d $${e}/ebin -a ! -d $(DEPS_DIR)/$${edep} ]; then				\
	        ln -s $${e} $(DEPS_DIR)/$${edep};						\
	      fi;										\
	    done;										\
	elif [ -f $</Makefile ]; then								\
	    ( cd $< && env ERLC_OPTS=+debug_info $(MAKE) ) || exit 1;				\
	elif [ -d $</src ]; then								\
	    ( cd $< && env ERLC_OPTS=+debug_info $(MAKE) -f $(ERL_MK_FILENAME) ) || exit 1;	\
	fi;											\
	touch $@

$(DEPS_DIR)/%:
	$(fetch_verbose) mkdir -p $(DEPS_DIR);							\
	$(call _dep_fetch_$(call get_dep_method,$(notdir $@)),$(notdir $@));			\
	if [ -f $@/configure.ac -o -f $@/configure.in ]; then					\
	  ( cd $@ && autoreconf -if )								\
	fi;											\
	if [ -f $@/configure ]; then								\
	  ( cd $@ && ./configure )								\
	fi;											\
	$(MAKE) --no-print-directory dep_patch_$(notdir $@)

dep_patch_%::
	@:

dep_build_%::
	@:

distclean: deps-clean

.PHONY: deps-clean
deps-clean:
	rm -rf $(DEPS_DIR)

define _dep_fetch_git
	git clone -q -n $(call get_dep_repo_git,$1) $(DEPS_DIR)/$1;				\
	(cd $(DEPS_DIR)/$(1) && git checkout -q $(call get_dep_version_git,$1))
endef

define _dep_fetch_hex
	mkdir $(DEPS_DIR)/$1;									\
	curl -s https://repo.hex.pm/tarballs/$1-$(call get_dep_version_hex,$1).tar |		\
	tar -xO contents.tar.gz | tar -C $(DEPS_DIR)/$1 -xzm
endef

define _dep_fetch_ln
	ln -s $(abspath $(word 2,$(dep_$1))) $(DEPS_DIR)/$1
endef

define _dep_fetch_cp
	cp -R $(abspath $(word 2,$(dep_$1))) $(DEPS_DIR)/$1
endef

define _dep_fetch_
	echo "error: missing rule dep_$1"; exit 1
endef

get_dep_method = $(word 1,$(dep_$1))

get_dep_repo_git = $(word 2,$(dep_$1))

get_dep_version = $(call get_dep_version_$(call get_dep_method,$1),$1)
get_dep_version_git = $(if $(word 3,$(dep_$1)),$(word 3,$(dep_$1)),HEAD)
get_dep_version_hex = $(word 2,$(dep_$1))
get_dep_version_cp = -
get_dep_version_ln = -

built_dep = touch $(DEPS_DIR)/$1/.dep_built;

### C source

inc = io:format(\"~s/erts-~s/include\", [code:root_dir(), erlang:system_info(version)]), halt()

c_src.mk:
	$(gen_verbose) printf "%s\n"								\
        '# Generated by erl.mk'									\
	''											\
	"ERL = $$(readlink -f `which erl`)"							\
	'ERTS_INCLUDE_DIR = $(shell erl -noshell -eval "$(inc)")'				\
	'OS = $$(shell uname -s)'								\
	'DEPS_DIR = $(DEPS_DIR)'								\
	''											\
	"CWARNINGS ?= \\"									\
	"       -Werror \\"									\
        "       -Wall \\"									\
        "       -Wpedantic \\"									\
        "       -Wsign-compare \\"								\
        "       -Wcast-align \\"								\
        "       -Wstrict-prototypes"								\
        'ifneq ($$(DEBUG),)'									\
        '  CEXTRA_FLAGS = -g -ggdb'								\
        'else'											\
        '  CEXTRA_FLAGS = -O2'									\
        'endif'											\
	''											\
	'CFLAGS ?= -std=c99 $$(CWARNINGS) $$(CEXTRA_FLAGS)'					\
	'CFLAGS += -MMD -MP -MF .$$<.d -I$$(ERTS_INCLUDE_DIR)'					\
	''											\
	'ifeq ($$(OS), Darwin)'									\
	'  LDFLAGS_NIF = -bundle -undefined dynamic_lookup'					\
	'  CFLAGS += -fPIC -fno-common'								\
	'else'											\
	'  LDFLAGS_NIF = -shared'								\
	'  CFLAGS += -fPIC'									\
	'endif'											\
	''											\
	'ifneq ($$(MAKECMDGOALS),clean)'							\
	'-include .*.d'										\
	'endif'											\
	''											\
	'# remove ourselves if erl is not the same as when we were generated'			\
	'ifneq ($$(shell readlink -f `which erl`),$$(ERL))'					\
	'$$(shell rm -f c_src.mk)'								\
	"endif" > $@

### Compatibility with rebar

.PHONY: rebar-files
rebar-files: rebar.config src/$(_APP).app.src.script

rebar.config: .erl.mk.app
	$(gen_verbose) printf -- '$(subst $(newline),\n,$(rebar_config))' > $@

define rebar_config
%%%% generated by erl.mk for rebar compatibility - do not remove this line
{deps, [
$(call tuplelist,										\
    $(foreach d,$(DEPS),									\
        $(if $(filter hex,$(call get_dep_method,$(d))),						\
            {$(d)$(comma)"$(call get_dep_version_hex,$(d))"},					\
            $(if $(filter git,$(call get_dep_method,$(d))),					\
                {$(d)$(comma){git$(comma)							\
                "$(call get_dep_repo_git,$(d))"$(comma)						\
                "$(call get_dep_version_git,$(d))"}}))))
]}.
$(call rebar_pre_hooks)
$(call rebar_post_hooks)
endef

ifneq ($(SUBDIRS),)
define rebar_pre_hooks
{pre_hooks,[
{compile,"$(MAKE) build-deps"},
$(call tuplelist, $(foreach s,$(SUBDIRS),{compile,"$(MAKE) $(s)"}))
]}.
endef
define rebar_post_hooks
{post_hooks,[
$(call tuplelist, $(foreach s,$(SUBDIRS),{clean,"$(MAKE) -C $(s) clean"}))
]}.
endef
endif

src/$(_APP).app.src.script: $(_APP_FILE)
	$(gen_verbose) echo "%% generated my erl.mk for rebar compatibility" > $@ && cat $< >> $@

### Helpers

# Used to be:
#   $(shell erl -noshell -eval 'io:write(list_to_atom("$1")),halt()')
# which is 100% correct, but slow.
# Current function is not perfect, but good enough.
define mkatom
$(shell echo $1 | awk "/^[a-z][a-zA-Z0-9_@]*$$/ {print \$$1 ; next} \
                       {printf \"'%s'\", \$$1 }")
endef

define mkatomlist
$(subst $(space),$(comma),$(foreach m,$1,$(call mkatom,$(m))))
endef

define tuplelist
$(subst }$(space){,}$(comma)\n{,$(strip $1))
endef
