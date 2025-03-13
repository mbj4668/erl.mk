#include "erl_nif.h"

static ERL_NIF_TERM hello_world(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    return enif_make_string(env, "Hello world", ERL_NIF_UTF8);
}

static ErlNifFunc nif_funcs[] = {
    {"hello", 0, hello_world}
};

ERL_NIF_INIT(n, nif_funcs, NULL, NULL, NULL, NULL)
