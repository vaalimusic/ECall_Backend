-module(ecall_gate).

-export([allow/2, allow/3, reset/0]).

-define(TABLE, ecall_gate).

allow(Key, IntervalMs) ->
    allow(Key, IntervalMs, erlang:monotonic_time(millisecond)).

allow(_Key, IntervalMs, _NowMs) when not is_integer(IntervalMs); IntervalMs =< 0 ->
    ok;
allow(Key, IntervalMs, NowMs) ->
    ensure_table(),
    ExpiresAt = NowMs + IntervalMs,
    case ets:insert_new(?TABLE, {Key, ExpiresAt}) of
        true ->
            ok;
        false ->
            case ets:lookup(?TABLE, Key) of
                [{Key, ExistingExpiresAt}] when ExistingExpiresAt =< NowMs ->
                    ets:delete(?TABLE, Key),
                    case ets:insert_new(?TABLE, {Key, ExpiresAt}) of
                        true -> ok;
                        false -> {error, rate_limited}
                    end;
                _ ->
                    {error, rate_limited}
            end
    end.

reset() ->
    ensure_table(),
    ets:delete_all_objects(?TABLE),
    ok.

ensure_table() ->
    case ets:info(?TABLE) of
        undefined ->
            try ets:new(?TABLE, [named_table, public, set, {read_concurrency, true}, {write_concurrency, true}]) of
                _ -> ok
            catch
                error:badarg -> ok
            end;
        _ ->
            ok
    end.
