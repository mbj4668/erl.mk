# Makefile for erlang applications

A simpler, smaller and less capable alternative to erlang.mk, that
doesn't mess with file modification times.

The idea is the same as erlang.mk, i.e., include `erl.mk` in your
`Makefile` in the top directory of an erlang application, possibly
customize, and you're done.

Supports downloading and build of external dependencies and running
tests.

Does not support build of erlang releases.

# Getting started

## Simplest possible application

If you have an erlang-only application, create a directory with the
same name as the application, put the erlang files in `src`, and
create a `Makefile` in the application directory:

```
myapp
├── Makefile
└── src
    └── myapp.erl
```

The `Makefile` should look like this:

```makefile
include erl.mk

erl.mk:
	curl -s -O https://raw.githubusercontent.com/mbj4668/erl.mk/main/$@
```
Now you can run `make`.  `erl.mk` will be downloaded and the erlang
code compiled.

```shell
$ make
...
$ tree
.
├── ebin
│   ├── myapp.app
│   └── myapp.beam
├── erl.mk
├── Makefile
└── src
    └── myapp.erl
```

Note that `erl.mk` creates the `.app` file as well.

## Adding a dependency

Suppose your application needs to use `eclip`.  Modify the `Makefile`
to:

```makefile
DEPS = eclip
dep_eclip = git https://github.com/mbj4668/eclip.git

include erl.mk

erl.mk:
	curl -s -O https://raw.githubusercontent.com/mbj4668/erl.mk/main/$@
```

Then simply run `make` again to download and build the dependency.

# Details

## Prerequisites

`curl` is used to fetch hex packages.

`git` is used to fetch git packages.

`rebar3` is used to build downloaded dependencies that need rebar.

## Build

By default, erl.mk uses erlc's compile server in order to speed up the
build.  To disable this behavior, set `ERLC_USE_SERVER = false`
before including erl.mk.

### The application resource file

When the code is built, erl.mk generates the required application
resource file `ebin/NAME.app`.

It can be generated in two ways:

#### Using `src/NAME.app.src`

If there is a file `src/NAME.app.src`, erl.mk will create
`ebin/NAME.app` from the contents of this file with the following
variables substituted:

- `%APP%` - the name of the application
- `%VSN%` - the version of the application as a double quoted string
- `%DESCRIPTION%` - the value of `$(DESCRIPTION)` as a double quoted string
- `%MODULES%` - a comma separated list of the modules in the application
- `%APPLICATIONS%` - a comma separated list of applications, calculated
                    from `DEPS` and `LOCAL_DEPS`.

#### Automatically generated

If `src/NAME.app.src` is not found, erl.mk will generate
`ebin/NAME.app` with default information.

If a file `NAME_app.erl` is found in `src`, it is used as the start
module in the app file.

### C source

There is no automatic handling of C files.  However, it is possible to
generate a file `c_src.mk` with useful variables.

Put the C source in `c_src`, and create a `Makefile` there.  When the
code is built, erl.mk will invoke the default target in that
makefile.

```makefile
include c_src.mk

c_src.mk:
	$(MAKE) -f ../erl.mk $@
```

Unless `CFLAGS` is set, `c_src.mk` sets `CFLAGS` to compile for `c99`,
some useful warnings, and `-Werror`.  It also sets `LDFLAGS_NIF`,
which is supposed to be used when linking a nif.

Here's a full example of a Makefile for a simple nif:
```makefile
NIF = ../priv/my_nif.so

all: $(NIF)

include c_src.mk

c_src.mk:
	$(MAKE) -f ../erl.mk $@

SOURCES := $(wildcard *.c)
OBJS := $(SOURCES:%.c=./%.o)

$(NIF): $(OBJS)
	$(CC) $^ $(LDFLAGS_NIF) -o $@

debug:
	$(MAKE) DEBUG=true all

clean:
	rm -f ../priv/*.so ./*.so ./*.o *.o
```

### Generated erlang modules

If your application uses generated erlang modules, set
`GENERATED_ERL_MODULES` to a space-separated list of the names of
these modules.  Then add rules to generate the erlang source files in
the `src` directory.

```makefile
GENERATED_ERL_MODULES = my_generated_mod

include erl.mk

...

src/my_generated_mod.erl: src/my_generated_mod.in
	sed -e ... $< > $@
```

### Build-time erlang modules

If your application contains a module that is used only during build
time, it should not be listed in the `modules` field in the
application resource file.  This can be controlled with
`EXCLUDE_ERL_MODULES`:

```makefile
EXCLUDE_ERL_MODULES = my_build
```

## Handling of dependencies

The handling of dependencies is similar to erlang.mk, except there is
no built-in list of packages.  Also, the way packages are patched is
different from erlang.mk.

Add the name of the application to the variable `DEPS` if it is a
run-time dependency that needs to be fetched and compiled.  Add to
`LOCAL_DEPS` if it is a run-time dependency that doesn't need to be
fetched and compiled, e.g., an OTP application.  Add to `TEST_DEPS`
if the dependency is used only in tests, and to `BUILD_DEPS` for
dependencies used only for building the project.

Also add a variable `dep_NAME` on the form:

- `git REPO [COMMIT/TAG/BRANCH]`
- `hex VERSION`
- `ln DIRNAME`
- `cp DIRNAME`

For example:
```makefile
DEPS = eclip idna
LOCAL_DEPS = mnesia
TEST_DEPS = mytests

dep_eclip = git https://github.com/mbj4668/eclip.git
dep_idna = hex 6.1.1
dep_mytests = ln ~/src/mytests
```

### Fetching, patching and building dependencies

The following steps are performed when erl.mk needs to fetch a
dependency:

1. Fetch the package using the declared fetch method.
2. If the package contains a `configure.ac` or `configure.in` file,
   run `autoreconf -if`.
3. If the package contains a `configure` script, run it.
4. Build the target `dep_patch_NAME`.

You can extend the target `dep_patch_NAME::` with additional commands
to run before building the package.

For example, the following rule patches `mjson` to be built for the
AtomVM:

```makefile
dep_patch_mjson::
	echo "ERLC_OPTS += -DNO_LISTS_TO_INTEGER_2" >> $(DEPS_DIR)/mjson/Makefile
```

The following steps are performed when erl.mk builds a dependency:

1. Build the target `dep_build_NAME`.
2. If the package was built by the target  `dep_build_NAME`, we're done.
   Else if the package contains a `rebar.config` file, run `rebar3`, else
   if the package contains a `Makefile`, run `make`, else
   use `erl.mk` itself to build.

If the package cannot be built using `rebar3` or `make` as described
above, you can extend the target `dep_build_NAME::` with commands to
build the package, and then create the file
`$(DEPS_DIR)/.erl_mk_dep_built_NAME`.

For example, to build `erlfmt` as an escript:

```makefile
dep_build_erlfmt::
	( cd $(DEPS_DIR)/erlfmt && make release && touch $(DEPS_DIR)/.erl_mk_dep_built_erlfmt ) \
	|| exit 1
```

### Updating dependencies

If a dependency needs to be updated to a new version, update the
`dep_NAME` variable in your `Makefile`, and remove `deps/dep_NAME`.

## Tests

There is built-in support for dialyzer and for running eunit, lux and
custom tests.

### dialyzer

Do `make dialyzer` to run dialyzer over the code base.  Set
`DIALYZER_OPTS` to customize the way dialyzer is invoked.

erl.mk will first create a PLT with all dependencies and all OTP
applications used.  Set `DIALYZER_PLT_OPTS` to pass
additional parameters to dialyzer when the PLT is built, and
`PLT_APPS` to add additional applications to the PLT.

The variable `DIALYZER_PLT` can be set to override the name of the PLT
file.  This can be used to do custom build of the PLT, e.g,:

```makefile
DIALYZER_PLT = .my.plt
$(DIALYZER_PLT):
	dialyzer --build-plt --output_plt $(DIALYZER_PLT) \
      --apps kernel stdlib sasl
```

### eunit

To run all tests, including eunit do:

```shell
$ make test
```

To run the eunit tests do:

```shell
$ make eunit
```

erl.mk will recompile all modules with the variable `TEST` set, if
needed.

To put eunit tests in your code. do:

```
-ifdef(TEST).

-include_lib("eunit/include/eunit.hrl").

%%% your eunit tests

-endif.
```

You can also write eunit tests in a separate module.  In this case,
write a module `test/*_tests.erl`.

It is also possible to run tests in a single module:

```shell
$ make eunit t=mymod
```

or just a single test:

```shell
$ make eunit t=mymod:my_test
```

The handling of eunit tests is the same as in erlang.mk.

The variable `EUNIT_OPTS` can be set to a list of options to pass to
`eunit`, for example:

```
EUNIT_OPTS = verbose,{print_depth,9999}
```

The variable `EUNIT_ERL_OPTS` can be set to pass options to `erl` when
running eunit tests.

### lux

Put all lux files in `test/lux`, or in subdirectories of `test/lux`.
When this directory is found, erl.mk automatically adds lux as a
dependency if needed.

If you need to build anything before running a lux test, create a
`Makefile` in the same directory as the lux file, and create the
targets `build` and `clean` in the makefile.  Before running `lux`,
erl.mk will do `$(MAKE) build`, if a Makefile is found.

To run all tests, including lux do:

```shell
$ make test
```

To run the eunit tests do:

```shell
$ make lux
```

### Custom tests

If there is a file `test/Makefile`, erl.mk will run the `test` target
in this file when `make test` is called, and the `clean` target when
`make test-clean` is called.

### Starting an erlang shell

Do `make shell` to get an erlang shell with correct paths.

# API - i.e., targets defined to be used by user

```
all         - build everything (default target)
test        - run tests, if defined
dialyzer    - run dialyzer
eunit       - run eunit tests
lux         - run lux tests
shell       - start an erlang shell with correct paths
clean       - clean application
test-clean  - clean tests
distclean   - clean application, tests and remove dependencies
fetch-deps  - fetch dependencies
build-deps  - build dependencies

c_src.mk    - generate `c_src.mk` with useful variables
```

## Verbosity

The handling of verbosity is the same as in erlang.mk.

By default, erl.mk prints a short string to indicate how it builds a
target.

Do `make V=1` to show the full commands, and `make V=2` to get even
more details.

# Customization - variables

Set `DESCRIPTION` to a short description of the application.

Set `VERSION` to suppress erl.mk's version detection (git) for the
.app file.

Set `APP_ENV` to an erlang term that goes into the application file's
`env` field.

Set `SUBDIRS` to add more sub directories for the build and clean
passes.

Set `ERL_OPTS` to add options to `erl` for `make shell`.

Set `ERLC_OPTS` before including erl.mk to override default options to erlc.

Add to `ERLC_OPTS` after including erl.mk to add to default options to erlc.

Set `REMOVE_ERLC_OPTS` to remove options from `ERLC_OPTS` before calling erlc.

Set `ERLC_USE_SERVER` to `false` to avoid using erlc's compile server.

Set `GENERATED_ERL_MODULES` before including erl.mk to compile
generated modules.

Set `EXCLUDE_ERL_MODULES` to exclude modules from the `modules` field in the app file.

Set `DEPS` to a space-separated list of run-time dependencies.

Set `LOCAL_DEPS` to a space-separated list of additional run-time
dependencies (these won't be downloaded).

Set `BUILD_DEPS` to a space-separated list of build dependencies.

Set `TEST_DEPS` to a space-separated list of test dependencies.

Set `DIALYZER_PLT` to use a specific PLT, e.g., to use a custom built PLT.

Set `DIALYZER_PLT_OPTS` to pass options to dialyzer when the PLT is built.

Set `PLT_APPS` to add additional apps to the PLT.

Set `DIALYZER_OPTS` to pass options to dialyzer.

Set `EUNIT_OPTS` to a list of eunit options.

Set `EUNIT_ERL_OPTS` to add options to `erl` when running eunit tests.

# Customization - targets

Add to `all:` to build more.

Add to `clean:` and `distclean` to clean more.

Add to `test:` to test more.

# Why not erlang.mk?

The biggest drawback with erlang.mk is that it messes with the
modification time of source files.  In order to avoid this, erl.mk
uses plain make dependency tracking.  erl.mk is also generally faster
than erlang.mk.
