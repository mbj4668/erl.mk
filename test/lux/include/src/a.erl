-module(a).
-export([run/0]).

-include("foo.hrl").
-include_lib("include/src/bar.hrl").
-include_lib("kernel/include/logger.hrl").
-include_lib("dinc/include/dinc.hrl").


run() ->
    ok.
