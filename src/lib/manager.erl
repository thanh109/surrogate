%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% FILE: manager.erl
%
% AUTHOR: Jake Breindel
% DATE: 5-26-15
%
% DESCRIPTION:
%
% Manager class that runs in seperate
% process and manages download events.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-module(manager).
-export([pid_name/1, loop/1]).
-include("download_status.hrl").

pid_name(Account) ->
	list_to_atom(Account:id() ++ "-manager").

%%----------------------------------------------------------------------
%% Function: notify_subscriber/2
%% Purpose: Sends the subscriber the data if it exists
%% Args:   	Subscriber - Process monitoring events
%%			Data - data to send to the subscriber
%%----------------------------------------------------------------------
notify_subscriber(Subscriber, Data) ->
	case is_pid(Subscriber) of
		true ->
			Subscriber ! Data;
		false ->
			false
	end.

%%----------------------------------------------------------------------
%% Function: loop/1
%% Purpose: Loops the manager with an Account and default options
%% Args:   	Account - account cb record
%%			Downloads - OrderdDictionary of current downloads by id
%%			Subscriber - Process monitoring events
%%----------------------------------------------------------------------
loop(Account) ->
	register(pid_name(Account), self()),
	loop(Account, [], undefined).

%%----------------------------------------------------------------------
%% Function: loop/3
%% Purpose: Loops the manager with an Account, Downloads, and Subscriber
%% Args:   	Account - account cb record
%%			Downloads - OrderdDictionary of current downloads by id
%%			Subscriber - Process monitoring events
%%----------------------------------------------------------------------
loop(Account, Downloads, Subscriber) ->
	receive

		%%%%%%%%%%%%%%%%%%%%%
		%% Client Messages %%
		%%%%%%%%%%%%%%%%%%%%%

		%%
		% subscriber connects to manager
		%%
		{subscriber_connect, Subscriber} ->
			notify_subscriber(Subscriber, {downloads, Downloads}),
			loop(Account, Downloads, Subscriber);

		%%
		% subscriber sent links to the manager
		%%
		{subscriber_downloads, Downloads} ->
			loop(Account, Downloads, Subscriber);
		
		%%
		% called when the subscriber wants to refresh their downloads
		%%
		{subscriber_refresh, Subscriber} ->
			notify_subscriber(Subscriber, {downloads, Downloads}),
			loop(Account, Downloads, Subscriber);

		%%
		% subscriber no longer is connected
		%%
		{subscriber_disconnect, _} ->
			loop(Account, Downloads, undefined);
			
		%%%%%%%%%%%%%%%%%%%%%%%
		%% Download Messages %%
		%%%%%%%%%%%%%%%%%%%%%%%
		
		%%
		% download is not found
		%%
		{download_not_found, Download} ->
			UpdatedDownload = Download:set(status, ?DL_NOT_FOUND),
			case UpdatedDownload:save() of
				{ok, SavedDownload} ->
					notify_subscriber(Subscriber, {on_download_not_found, [{download, Download}]});
				{error, Errors} ->
					notify_subscriber(Subscriber, {on_download_error, [{download, Download}, {errors, Errors}]})
			end,
			loop(Account, Downloads, Subscriber);
		
		%%
		% download has been accquired
		%%
		{download_accquired, Download} ->
			UpdatedDownload = Download:set(status, ?DL_PENDING),
			case UpdatedDownload:save() of
				{ok, SavedDownload} ->
					notify_subscriber(Subscriber, {on_download_accquired, [{download, Download}]});
				{error, Errors} ->
					notify_subscriber(Subscriber, {on_download_error, [{download, Download}, {errors, Errors}]})
			end,
			loop(Account, Downloads, Subscriber);
			
		%%
		% download has started
		%%
		{download_started, Download} ->
			UpdatedDownload = Download:set(status, ?DL_ACTIVE),
			case UpdatedDownload:save() of
				{ok, SavedDownload} ->
					notify_subscriber(Subscriber, {on_download_started, [{download, Download}]});
				{error, Errors} ->
					notify_subscriber(Subscriber, {on_download_error, [{download, Download}, {errors, Errors}]})
			end,
			loop(Account, Downloads, Subscriber);
			
		%%
		% download has finished
		%%
		{download_complete, Download} ->
			UpdatedDownload = Download:set(status, ?DL_COMPLETED),
			case UpdatedDownload:save() of
				{ok, SavedDownload} ->
					notify_subscriber(Subscriber, {on_download_complete, [{download, Download}]});
				{error, Errors} ->
					notify_subscriber(Subscriber, {on_download_error, [{download, Download}, {errors, Errors}]})
			end,
			loop(Account, Downloads, Subscriber)
			
	end.