-module(n).

-export([nonif/0, nif/0]).
-export([hello/0]).

-on_load(nif_load/0).

nonif() ->
    io:format("hello from Erlang\n", []),
    erlang:halt(0).

nif() ->
    io:format("hello from nif: ~0p\n", [hello()]),
    erlang:halt(0).

hello() ->
    nif_only().

nif_load() ->
%%    Path = filename:join(code:priv_dir(n), atom_to_list(?MODULE)),
    Path = filename:join("priv", atom_to_list(?MODULE)),
    erlang:load_nif(Path, 0).

nif_only() ->
    erlang:nif_error(not_loaded).
