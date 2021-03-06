-module(rc_socket_user_adapter).
-behaviour(gen_server).
-behaviour(raibaru_user_adapter).

%% API
-export([ start/1
        , start_link/1
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
        , socket
        }).

%%%===================================================================
%%% API
%%%===================================================================

start(Socket) ->
    gen_server:start(?MODULE, [Socket], []).

start_link(Socket) ->
    gen_server:start_link(?MODULE, [Socket], []).


%%%
%%% User Adapter API
%%%

user_controller(SC) ->
    gen_server:call(SC, user_controller).

send_message(SC, Message) ->
    gen_server:call(SC, {send, Message}).

send_game_invitation(SC, Invitation) ->
    gen_server:call(SC, {send, {game_invitation, Invitation}}).

send_game_invitation_accepted(SC, Invitation, Game) ->
    gen_server:call(SC, {send, {accepted, Invitation, Game}}).

send_game_invitation_denied(SC, Invitation) ->
    gen_server:call(SC, {send, {denied, Invitation}}).

send_game_started(SC, Game, GameSettings, Color, Why) ->
    gen_server:call(SC, {send, {game_started, Game, GameSettings, Color, Why}}).

send_move(SC, Game, Move) ->
    gen_server:call(SC, {send, {move, Game, Move}}).


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
init([Socket]) ->
    {ok, Pid} =
        raibaru_user_controller_sup:start_user_controller(?MODULE, self()),
    ok = inet:setopts(Socket, [{active, once}]),
    {ok, #state{ user_controller = Pid
               , socket = Socket
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
handle_call(user_controller, _From, S = #state{user_controller = UC}) ->
    {reply, UC, S};

handle_call({send, Message}, _From, S = #state{socket = Socket}) ->
    ok = gen_tcp:send(Socket, Message),
    {reply, ok, S};

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
handle_info({tcp_closed, _Socket}, State) ->
    {stop, tcp_closed, State};

handle_info({tcp, Socket, _Data}, State) ->
    inet:setopts(Socket, [{active, once}]),
    %% TODO: Parse message and handle
    {noreply, State};

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
