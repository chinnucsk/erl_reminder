-module(event).
-compile(export_all).
-import(myio,[p/1,p/2]).
-record(state, {server, name="", to_go=0}).

%% ====================================================================
%% API functions
%% ====================================================================
start(EventName, Delay) ->
    spawn(?MODULE, init, [self(), EventName, Delay]).

start_link(EventName, Delay) ->
    spawn_link(?MODULE, init, [self(), EventName, Delay]).

init(Server, EventName, DateTime) ->
                 loop(#state{server=Server,
                             name=EventName,
                             to_go=time_to_go(DateTime)}).

cancel(Pid) ->
    %% Monitor in case the process is already dead.
    Ref = erlang:monitor(process, Pid),
    Pid ! {self(), Ref, cancel},
    receive
        {Ref, ok} ->
            erlang:demonitor(Ref, [flush]), % fulsh msg
            ok;
        {'DOWN', Ref, process, Pid, _Reason} ->
            ok
end.


%% ====================================================================
%% Internal functions
%% ====================================================================
%% Loop uses a list for times in order to go around the ~49 days limit on timeouts.
loop(S = #state{server=Server, to_go=[T|Next]}) ->
    receive
        {Server, Ref, cancel} -> Server ! {Ref, ok}
    after T*1000 ->
        if Next =:= [] -> Server ! {done, S#state.name};
           Next =/= [] -> loop(S#state{to_go=Next})
		end 
	end.

%% Because Erlang is limited to about 49 days (49*24*60*60)  in seconds.
normalize(N) ->
    Limit = 49*24*60*60,
    [N rem Limit | lists:duplicate(N div Limit, Limit)].

% Use Erlang’s datetime ({{Year, Month, Day}, {Hour, Minute, Second}})
time_to_go(TimeOut={{_,_,_}, {_,_,_}}) ->
    Now = calendar:local_time(),
    ToGo = calendar:datetime_to_gregorian_seconds(TimeOut) - calendar:datetime_to_gregorian_seconds(Now),
    Secs = if	ToGo > 0  -> ToGo; 
				ToGo =< 0 -> 0
		   end,
    normalize(Secs).