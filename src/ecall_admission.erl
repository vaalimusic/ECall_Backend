-module(ecall_admission).

-export([admit/3, snapshot/0]).

snapshot() ->
    #{
        process_count => erlang:system_info(process_count),
        process_limit => erlang:system_info(process_limit),
        run_queue => erlang:statistics(run_queue),
        total_memory => erlang:memory(total)
    }.

admit(MaxProcesses, MaxRunQueue, MaxMemoryBytes) ->
    Snapshot = snapshot(),
    case first_limit_hit(MaxProcesses, MaxRunQueue, MaxMemoryBytes, Snapshot) of
        none -> {ok, Snapshot};
        Reason -> {error, Reason, Snapshot}
    end.

first_limit_hit(MaxProcesses, MaxRunQueue, MaxMemoryBytes, Snapshot) ->
    ProcessCount = maps:get(process_count, Snapshot),
    RunQueue = maps:get(run_queue, Snapshot),
    TotalMemory = maps:get(total_memory, Snapshot),
    case over_limit(MaxProcesses, ProcessCount) of
        true -> process_limit;
        false ->
            case over_limit(MaxRunQueue, RunQueue) of
                true -> run_queue_limit;
                false ->
                    case over_limit(MaxMemoryBytes, TotalMemory) of
                        true -> memory_limit;
                        false -> none
                    end
            end
    end.

over_limit(undefined, _Value) -> false;
over_limit(nil, _Value) -> false;
over_limit(Max, Value) when is_integer(Max), Max > 0 -> Value >= Max;
over_limit(_Max, _Value) -> false.
