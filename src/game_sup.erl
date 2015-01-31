-module(game_sup).
-behaviour(supervisor).

%% API
-export([ start_link/0
        , start_game/2
        , accept_invitation/1
        ]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%%===================================================================
%%% API functions
%%%===================================================================

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

start_game(Player1, Player2) ->
    supervisor:start_child(?SERVER, [Player1, Player2]).

accept_invitation(Invitation) ->
    Challenger = game_invitation:challenger(Invitation),
    supervisor:start_child(?SERVER, [Challenger, self()]).


%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

init([]) ->

    SupFlags = {simple_one_for_one, 1000, 3600},
    ChildSpec = {game,
                 {game, start_link, []},
                 temporary,
                 2000,
                 worker,
                 [game]},

    {ok, {SupFlags, [ChildSpec]}}.


%%%===================================================================
%%% Internal functions
%%%===================================================================