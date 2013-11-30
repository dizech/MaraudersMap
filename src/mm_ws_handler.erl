-module(mm_ws_handler).
-behaviour(cowboy_websocket_handler).
-include("mm_records.hrl").

-export([init/3]).
-export([websocket_init/3]).
-export([websocket_handle/3]).
-export([websocket_info/3]).
-export([websocket_terminate/3]).

-define(WS_KEY, {pubsub, ws_broadcast}).

init({tcp, http}, _Req, _Opts) ->
	{upgrade, protocol, cowboy_websocket}.

websocket_init(_TransportName, Req, _Opts) ->
	gproc:reg({p, l, ?WS_KEY}),
	erlang:start_timer(1000, self(), <<"Hello!">>),
	{ok, Req, undefined_state}.

websocket_handle({text, Msg}, Req, State) ->
	[{event, Event}, {data, Data}] = jsx:decode(Msg, [{labels, attempt_atom}]),
	case Event of
		<<"get_trainers">> ->
			Bin = enc(<<"trainers">>, mm_analyzer:get_trainers()),
			{reply, {text, Bin}, Req, State};
		<<"get_trained_coords">> ->
			Bin = enc(<<"trained_coords">>, mm_analyzer:get_trained_coords()),
			{reply, {text, Bin}, Req, State};
		<<"start_training">> ->
			[Trainer, X, Y] = Data,
			case mm_analyzer:start_training(Trainer, X, Y) of
				{training_started, TrainerLoc} ->
					Bin = enc(<<"training_started">>, TrainerLoc),
					{reply, {text, Bin}, Req, State};
				{already_training, TrainerLoc} ->
					Bin = enc(<<"already_training">>, TrainerLoc),
					{reply, {text, Bin}, Req, State};
				{not_trainer, TrainerLoc} ->
					Bin = enc(<<"not_trainer">>, TrainerLoc),
					{reply, {text, Bin}, Req, State}
			end;
		<<"end_training">> ->
			[Trainer, X, Y] = Data,
			case mm_analyzer:end_training(Trainer, X, Y) of
				{training_ended, TrainerLoc} ->
					Bin = enc(<<"training_ended">>, TrainerLoc),
					{reply, {text, Bin}, Req, State};
				{not_trainer, TrainerLoc} ->
					Bin = enc(<<"not_trainer">>, TrainerLoc),
					{reply, {text, Bin}, Req, State}
			end;
		_ -> % default for non-recognized text
			{ok, Req, State}
	end;
websocket_handle(_Data, Req, State) ->
	{ok, Req, State}.

websocket_info({training_received, Trainer}, Req, State) ->
	Bin = enc(<<"training_received">>, Trainer),
	{reply, {text, Bin}, Req, State};
websocket_info({pulse}, Req, State) ->
	erlang:start_timer(1000, self(), {pulse}),
	Bin = enc(<<"position">>, null),
	{reply, {text, Bin}, Req, State};
websocket_info({timeout, _Ref, _Msg}, Req, State) ->
	erlang:start_timer(1000, self(), <<"Timeout">>),
	Bin = enc(<<"position">>, get_test()),
	{reply, {text, Bin}, Req, State};
websocket_info(_Info, Req, State) ->
	{ok, Req, State}.

websocket_terminate(_Reason, _Req, _State) ->
	gproc:unreg({p, l, ?WS_KEY}),
	ok.
	
get_test() ->
	[
		[{l, <<"Tester">>}, {x, 0}, {y, 0}],
		[{l, <<"Tester">>}, {x, 1}, {y, 0}],
		[{l, <<"Tester">>}, {x, 2}, {y, 0}],
		[{l, <<"Tester">>}, {x, 3}, {y, 0}],
		[{l, <<"Tester">>}, {x, 4}, {y, 0}],
		[{l, <<"Tester">>}, {x, 5}, {y, 0}],
		[{l, <<"Tester">>}, {x, 6}, {y, 0}],
		[{l, <<"Tester">>}, {x, 7}, {y, 0}],
		[{l, <<"Tester">>}, {x, 8}, {y, 0}],
		[{l, <<"Tester">>}, {x, 9}, {y, 0}],
		[{l, <<"Tester">>}, {x, 10}, {y, 0}],
		[{l, <<"Tester">>}, {x, 11}, {y, 0}],
		[{l, <<"Tester">>}, {x, 12}, {y, 0}],
		[{l, <<"Tester">>}, {x, 13}, {y, 0}],
		[{l, <<"Tester">>}, {x, 14}, {y, 0}],
		[{l, <<"Tester">>}, {x, 15}, {y, 0}],
		[{l, <<"Tester">>}, {x, 16}, {y, 0}],
		[{l, <<"Tester">>}, {x, 17}, {y, 0}],
		[{l, <<"Tester">>}, {x, 18}, {y, 0}],
		[{l, <<"Tester">>}, {x, 19}, {y, 0}],
		[{l, <<"Tester">>}, {x, 20}, {y, 0}],
		[{l, <<"Tester">>}, {x, 19}, {y, 1}],
		[{l, <<"Tester">>}, {x, 18}, {y, 2}],
		[{l, <<"Tester">>}, {x, 17}, {y, 3}],
		[{l, <<"Tester">>}, {x, 16}, {y, 4}],
		[{l, <<"Tester">>}, {x, 15}, {y, 5}],
		[{l, <<"Tester">>}, {x, 14}, {y, 6}],
		[{l, <<"Tester">>}, {x, 13}, {y, 7}],
		[{l, <<"Tester">>}, {x, 12}, {y, 8}],
		[{l, <<"Tester">>}, {x, 11}, {y, 9}],
		[{l, <<"Tester">>}, {x, 10}, {y, 10}],
		[{l, <<"Tester">>}, {x, 9}, {y, 11}],
		[{l, <<"Tester">>}, {x, 8}, {y, 12}]
	].
	
%% @doc Internal wrapper function to encode erlang to json in a pseudo-RPC form
-spec enc(Event, Data) -> Output when
	Event :: any(),
	Data :: any(),
	Output :: binary().
enc(Event, Data) ->
	jsx:encode([{event, Event}, {data, Data}]).