-module(main).
-export([start_dir_service/2, create/1, get/1, deactivate/1, quit/0]).

% NOTE TO GRADER: all io:format() usages are commented out but were used to debug in implementation

% Starts a directory service and file servers N and parameter R
start_dir_service(N, R) ->
    %io:format("Starting Directory Service\n"),
    % Create and register Directory Service
    case util:isDistributed() of
        true ->
            register(dir_service, self()),
            dir_service(N, R),
            io:format("Distributive method executed - PID for Directory Service: ~p\n", [self()]);
        false ->
            DirService = spawn_link(fun() -> dir_service(N, R) end),
            register(dir_service, DirService),
            io:format("Concurrent method executed - PID for Directory Service: ~p\n", [DirService])
    end.

% Directory service initialization processes
dir_service(N, R) ->
    %io:format("Creating file directories 'servers' and 'downloads'\n"),
    % Create required directories
    util:createDir("servers"),
    util:createDir("downloads"),
    
    % Create and initialize file servers
    FileServers = create_file_servers(N, R),
    %io:format("File server list: ~p'\n", [FileServers]),
    link_servers_in_ring(FileServers),
    dir_service_loop(FileServers, R, N).

% Directory service uses this to loop through receive messages
dir_service_loop(FileServers, R, N) ->
    receive
        % Receiving create message -> sends create message to the file server found from hash message
        {create, Filename} ->
            Hash = util:hashFileName(Filename, N),
            {_Name, ServerPid} = lists:nth(Hash + 1, FileServers),
            Content = util:readFile("input/" ++ atom_to_list(Filename)),
            ServerPid ! {create, Filename, Content, R},
            dir_service_loop(FileServers, R, N);
        % Receiving get message -> sends get message to the file server found from hash message
        {get, Filename} ->
            Hash = util:hashFileName(Filename, N),
            {_Name, ServerPid} = lists:nth(Hash + 1, FileServers),
            ServerPid ! {get, Filename, R, self()},
            dir_service_loop(FileServers, R, N);
        % Receiving inactive message -> sends inactive message to the stated file server
        {inactive, ServerName} ->
            [ServerPid] = [Pid || {Name, Pid} <- FileServers, Name == ServerName],
            ServerPid ! inactive,
            dir_service_loop(FileServers, R, N);
        % Receiving quit message -> sends quit message to all file servers and then exits directory service and shuts down program
        quit ->
            %io:format("Quit message executed inside dir_service_loop\n"),
            [ServerPid ! quit || {_, ServerPid} <- FileServers],
            init:stop(),  % Call init:stop() before exiting
            exit(normal)  % Exit the directory server
    end.

% Client functions - These run in temporary client nodes
% For each one, use ds@localhost node if distributed otherwise use the same local process

% Sends create message and filename to Directory service
create(Filename) ->
    case util:isDistributed() of
        true ->
            {dir_service, 'ds@localhost'} ! {create, Filename};
        false ->
            dir_service ! {create, Filename}
        end.
% Sends get message and filename to Directory service
get(Filename) ->
    case util:isDistributed() of
        true ->
            {dir_service, 'ds@localhost'} ! {get, Filename};
        false ->
            dir_service ! {get, Filename}
        end.  
% Sends create message and servername to Directory service
deactivate(ServerName) ->
    case util:isDistributed() of
        true ->
            {dir_service, 'ds@localhost'} ! {inactive, ServerName};
        false ->
            dir_service ! {inactive, ServerName}
        end.
% Sends quit message to Directory service
quit() ->
    %io:format("Quit command executed from terminal\n"),
    case util:isDistributed() of
        true ->
            {dir_service, 'ds@localhost'} ! quit;
        false ->
            dir_service ! quit
        end.

% Create all file servers and their related processes
create_file_servers(N, R) ->
    %io:format("Executing the creation of the file servers\n"),
    ServerNames = [list_to_atom("fs" ++ integer_to_list(I)) || I <- lists:seq(0, N-1)],
    case util:isDistributed() of
        true ->
            [{Name, spawn(list_to_atom(atom_to_list(Name) ++ "@localhost"), fun() -> file_server(Name, R) end)} || Name <- ServerNames];
        false ->
            [{Name, spawn_link(fun() -> file_server(Name, R) end)} || Name <- ServerNames]
    end.

% Links all the servers in a ring so that message forwarding can occur
link_servers_in_ring(Servers) ->
    ServerPids = [Pid || {_, Pid} <- Servers],
    lists:zipwith(
        fun(Server, Next) -> Server ! {set_next, Next} end,
        ServerPids,
        % shifts the list of PIDs one position, making the first element the last, thus creating a circular sequence.
        tl(ServerPids) ++ [hd(ServerPids)]
    ).

% Creates the individual file server directory and spawns its receive messages loop
file_server(Name, R) ->
    %io:format("Creating file server: ~p\n", [Name]),
    ServerDir = "servers/" ++ atom_to_list(Name),
    util:createDir(ServerDir),
    file_server_loop(Name, R, undefined, sets:new(), true).

% Each file server uses this to loop through receive messages
file_server_loop(Name, R, NextServer, Files, Active) ->
    receive
        {set_next, Next} ->
            %io:format("Forces the first instance of the file_server_loop to be run again\n"),
            file_server_loop(Name, R, Next, Files, Active);
            
        {create, Filename, Content, RemainingR} ->
            %io:format("Received message create for file: ~p with R of ~p\n", [Filename, R]),
            NewFiles = case Active of
                true ->
                    FilePath = "servers/" ++ atom_to_list(Name) ++ "/" ++ atom_to_list(Filename),
                    util:saveFile(FilePath, Content),
                    sets:add_element(Filename, Files);
                false ->
                    Files
            end,
            
            if RemainingR > 1 ->
                NextServer ! {create, Filename, Content, RemainingR - 1};
                true -> ok
            end,
            file_server_loop(Name, R, NextServer, NewFiles, Active);
            
        {get, Filename, RemainingR, Client} ->
            %io:format("Received message get for file: ~p with R of ~p\n", [Filename, R]),
            case {Active, sets:is_element(Filename, Files)} of
                {true, true} ->
                    FilePath = "servers/" ++ atom_to_list(Name) ++ "/" ++ atom_to_list(Filename),
                    Content = util:readFile(FilePath),
                    util:saveFile("downloads/" ++ atom_to_list(Filename), Content);
                _ when RemainingR > 1 ->
                    NextServer ! {get, Filename, RemainingR - 1, Client};
                _ ->
                    %io:format("Error message sent to downloads folder\n"),
                    util:saveFile("downloads/" ++ atom_to_list(Filename) ++ ".err", ""),
                    Client ! {error, Filename}
            end,
            file_server_loop(Name, R, NextServer, Files, Active);
            
        inactive ->
            %io:format("File server ~p now is inactive\n", [Name]),
            file_server_loop(Name, R, NextServer, Files, false);

        quit ->
            %io:format("FileServer ~p shutting down...\n", [Name]),
            exit(normal)
    end.