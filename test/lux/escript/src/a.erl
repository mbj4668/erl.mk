-module(a).

-export([main/1]).

main(Args) ->
    io:format("Got args: ~p\n", [Args]).
