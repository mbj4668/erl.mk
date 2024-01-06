-module(a).

-export([run/0]).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

run() ->
    ok.

-ifdef(TEST).
ok_test() ->
    ?assertEqual([1], lists:reverse([1])).

nok_test() ->
    ?assertEqual([2], lists:reverse([1])).

-endif.
