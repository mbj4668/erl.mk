# Makefile for erlang applications

A simpler, smaller and less capable alternative to erlang.mk.

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
	curl -O https://raw.githubusercontent.com/mbj4668/erl.mk/main/$@
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
	curl -O https://raw.githubusercontent.com/mbj4668/erl.mk/main/$@
```

Then simply run `make` again to download and build the dependency.

# Details

## Prerequisites

`curl` is used to fetch hex packages.

`git` is used to fetch git packages.

`rebar3` is used to build downloaded dependencies that need rebar.

## Build

By default, erl.mk uses erlc's compile server in order to speed up the
build.  To disable this behaviour, set `ERLC_USE_SERVER = false`
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
- `%VSN%` - the version of the application
- `%MODULES%` - a comma separated list of the modules in the application
- `%APPLICATIONS%` - a comma separated list of applications, calculated
                    from `DEPS` and `LOCAL_DEPS`.

#### Automatically generated

If `src/NAME.app.src` is not found, erl.mk will generate
`ebin/NAME.app` with default information.

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

...
```

### Generated erlang modules

If your application uses generated erlang modules, set `ERL_MODULES`
to a space-separated list of the names of these modules.  Then add
rules to generate the erlang source files in the `src` directory, and
a rule to remove the generated file.

```makefile
ERL_MODULES = my_generated_mod.erl

include erl.mk

...

src/my_generated_mod.erl: src/my_generated_mod.in
	sed -e ... $< > $@

clean: my-clean

my_clean:
	rm -f src/my_generated_mod.erl
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
no built-in list of packages.

Add the name of the application to the variable `DEPS` if it is a
run-time dependency that needs to be fetched and compiled.  Add to
`LOCAL_DEPS` if it is a run-time dependency that doesn't need to be
fetched and compiled, e.g., and OTP application.  Add to `TEST_DEPS`
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

## Tests

There is built-in support for dialyzer, and for running eunit, lux and
custom tests.

### dialyzer

Do `make dialyzer` to run dialyzer over the code base.  Set
`DIALYZER_OPTS` to customize the way dialyzer is onvoked.

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

### lux

Put all lux files in `test/lux`.  When this directory is found, erl.mk
automatically adds lux as a dependency if needed.

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
in this file when `make test` is called.

### Starting an erlang shell

Do `make shell` to get an erlang shell with correct paths.

# Why not erlang.mk?

The biggest drawback with erlang.mk is that it messes with the
modification time of source files.  In order to avoid this, erl.mk
uses plain make dependency tracking.
