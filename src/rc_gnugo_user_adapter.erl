-module(rc_gnugo_user_adapter).
-behaviour(gen_server).
-behaviour(raibaru_user_adapter).

%% API
-export([ start/0
        , game_map/1
        , show_board/2
        ]).

%% User Adapter API
-export([ user_controller/1
        , send_message/2
        , send_game_invitation/2
        , send_game_invitation_accepted/3
        , send_game_invitation_denied/2
        , send_game_started/5
        , send_move/3
        ]).

%% gen_server callbacks
-export([ init/1
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , terminate/2
        , code_change/3
        ]).

-record(state,
        { user_controller
        , map
        }).


%%%===================================================================
%%% API
%%%===================================================================

start() ->
    gen_server:start(?MODULE, [], []).

user_controller(Server) ->
    gen_server:call(Server, user_controller).

game_map(Server) ->
    gen_server:call(Server, game_map).

show_board(Server, Game) ->
    gen_server:cast(Server, {show_board, Game}).


send_message(_Server, _Message) ->
    %% Messages are ignored.
    ok.

send_game_invitation(Server, Invitation) ->
    gen_server:cast(Server, {game_invitation, Invitation}).

send_game_invitation_accepted(_Server, _Invitation, _Game) ->
    %% Ignored, GNU Go does not send game invitations.
    ok.

send_game_invitation_denied(_Server, _Invitation) ->
    %% Ignored, GNU Go does not send game invitations.
    ok.

send_game_started(Server, Game, GameSettings, Color, Why) ->
    gen_server:cast(Server, {game_started, Game, GameSettings, Color, Why}).

send_move(Server, Game, Move) ->
    gen_server:cast(Server, {move, Game, Move}).


%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    {ok, Pid} =
        raibaru_user_controller_sup:start_user_controller(?MODULE, self()),
    {ok, #state{ user_controller = Pid
               , map = rc_gnugo_game_map:new()
               }}.


%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call(user_controller, _From, State = #state{user_controller = UC}) ->
    {reply, UC, State};

handle_call(game_map, _From, State = #state{map = Map}) ->
    {reply, Map, State};

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.


%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast({game_invitation, Invitation}, State) ->
    UC = State#state.user_controller,
    ok = rc_user_controller:recv_game_invitation_accept(UC, Invitation),
    {noreply, State};

handle_cast({game_started, Game, GameSettings, Color, _Why}, S) ->
    %% TODO: Specify ruleset for GNU Go
    {ok, Ref} = gnugo:start(),
    NewMap = rc_gnugo_game_map:add(Game, Ref, Color, S#state.map),
    ok = gnugo:clear_board(Ref),
    ok = gnugo:boardsize(Ref, rc_game_settings:boardsize(GameSettings)),
    ok = gnugo:komi(Ref, rc_game_settings:komi(GameSettings)),
    case rc_game_settings:handicap(GameSettings) of
        H when H >= 2 -> {ok, _Vs} = gnugo:fixed_handicap(Ref, H);
        _             -> ok
    end,
    case Color of
        white -> ok;
        black -> ok = gnugo:genmove_async(Ref, Color)
    end,
    {noreply, S#state{map = NewMap}};

handle_cast({move, GameID, Move}, State = #state{map = Map}) ->
    {GameID, Ref, Color} = rc_gnugo_game_map:find_gnugo_ref(GameID, Map),
    ok = gnugo:play(Ref, other_color(Color), Move),
    ok = gnugo:genmove_async(Ref, Color),
    {noreply, State};

handle_cast({show_board, GameID}, State = #state{map = Map}) ->
    {GameID, Ref, _Color} = rc_gnugo_game_map:find_gnugo_ref(GameID, Map),
    ok = gnugo:showboard(Ref),
    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.


%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info({Ref, {data, {eol, Line}}}, State = #state{map = Map}) ->
    %% Received asynchronous reply from GNU Go.
    UC = State#state.user_controller,
    {ok, Move} = gnugo:receive_reply(Ref, [Line]),
    {GameID, Ref, _Color} = rc_gnugo_game_map:find_game_id(Ref, Map),
    ok = rc_user_controller:recv_move(UC, GameID, Move),
    {noreply, State};

handle_info({Ref, {exit_status, _Status}}, State = #state{map = Map}) ->
    NewMap = rc_gnugo_game_map:delete_gnugo_ref(Ref, Map),
    {noreply, State#state{map = NewMap}};

handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%%%===================================================================
%%% Internal functions
%%%===================================================================

other_color(black) -> white;
other_color(white) -> black.
