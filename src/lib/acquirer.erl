%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% FILE: acquirer.erl
%
% AUTHOR: Jake Breindel
% DATE: 6-4-15
%
% DESCRIPTION:
%
% Acquirer that acquires actual download
% links.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-module(acquirer).
-export([acquire/2, acquire_downloads/2]).
-include("download_status.hrl").

notify_manager(Account, Data) ->
	case manager:alive(Account) of
		false ->
			false;
		Pid ->
			Pid ! Data
	end.

acquire(Account, Download) ->
	erlang:display({acquire, Download}),
	Headers = [{"Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"}, 
			   {"User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2490.80 Safari/537.36"},
			   {"Accept-Language", "en-US,en;q=0.8"}],
	case httpc:request(get, {Download:display_url(), Headers}, [], []) of
		{ok, {{Version, 200, ReasonPhrase}, RespHeaders, Body}} ->
			erlang:display({body, Body});
		Request ->
			erlang:display(Request),
			error
	end.

acquire_downloads(Account, []) ->
	erlang:display({acquire_download, []}),
	ok;
acquire_downloads(Account, [Download|Downloads]) ->
	erlang:display({acquire_downloads, Downloads}),
	case Download:status() of
		?DL_PENDING ->
			erlang:display({status_pend, 0}),
			erlang:spawn(?MODULE, acquire, [Account, Download]);
		Status ->
			erlang:display({status, Status})
	end,
	acquire_downloads(Account, Downloads).