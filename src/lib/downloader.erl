%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% FILE: Downloader.erl
%
% AUTHOR: Jake Breindel
% DATE: 11-8-15
%
% DESCRIPTION:
%
% Downloads the file from the real url.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-module(downloader).
-export([execute/2]).

parse_file_name(FileName) ->
	case string:str(FileName, "\"") of
		0 ->
			FileName;
		Index ->
			string:substr(FileName, 0, Index - 1)
	end.

download_meta(HttpClient, Download) ->
	Headers = [{"User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2490.80 Safari/537.36"},
		   {"Accept-Language", "en-US,en;q=0.8"}],
	case httpc:request(head, {Download:real_url(), Headers}, [], [], HttpClient) of
		{ok, {{Version, 200, ReasonPhrase}, RespHeaders, Body}} ->
			ContentLengthStr = proplists:get_value("content-length", RespHeaders),
			{ContentLength, _} = string:to_integer(ContentLengthStr),
			ContentDispositionStr = proplists:get_value("content-disposition", RespHeaders),
			[_, FileNameStr] = string:tokens(ContentDispositionStr, "=\""),
			FileName = parse_file_name(FileNameStr),
			FileNameWithDir = download_file(FileName),
			MetaDownload = Download:set([{file, FileNameWithDir}, {length, ContentLength}]),
			case MetaDownload:save() of
				{ok, SavedDownload} ->
					{download, SavedDownload};
				{error, Errors} ->
					{error, Errors}
			end;
		Response ->
			{error, Response}
	end.

download_file(FileName) ->
	case boss_db:find_first(config) of
		undefined ->
			{error, "Cannot find Config"};
		Config ->
			Config:download_directory() ++ FileName
	end.

calc_byte_sum([], Sum) ->
	Sum;
calc_byte_sum([Elem|Elems], Sum) ->
	{_, LengthProps} = Elem,
	case proplists:get_value(length, LengthProps) of
		undefined ->
			calc_byte_sum(Elems, Sum);
		Length ->
			calc_byte_sum(Elems, Sum + Length)
	end.

notify_manager(Account, Download, Length, Now, Timestamps, SpeedOrddict) ->
	ByteCount = calc_byte_sum(orddict:to_list(SpeedOrddict), 0),
	Max = list_lib:list_max(Timestamps),
	Min = list_lib:list_min(Timestamps),
	TimeDiff = Max - Min,
	case (TimeDiff / 1000) of
		0 ->
			erlang:display({error, TimeDiff}),
			orddict:store(Now, [{length, Length}], orddict:new());
		DeltaTime ->
			ManagerName = manager:pid_name(Account),
			process_lib:find_send(ManagerName, {download_progress, [{download, Download}, 
											  {speed, ByteCount / DeltaTime}, 
											  {chunk_size, ByteCount}]}),
			orddict:store(Now, [{length, Length}], orddict:new())
	end.

update_speed(Account, Download, SpeedOrddict, Length) ->
	TimeMs = date_lib:now_to_milliseconds_hires(now()),
	case orddict:is_empty(SpeedOrddict) of
		true ->
			orddict:store(TimeMs, [{length, Length}], SpeedOrddict);
		false ->
			Timestamps = orddict:fetch_keys(SpeedOrddict),
			EarliestTimeMs = list_lib:list_min(Timestamps),
			case TimeMs - EarliestTimeMs of
				Diff when Diff < 1000 ->
					orddict:store(TimeMs, [{length, Length}], SpeedOrddict);
				Diff when Diff >= 1000 ->
					notify_manager(Account, Download, Length, TimeMs, Timestamps, SpeedOrddict)
			end
	end.

download(Account, Download, UpdaterPid) ->
	receive
		{http, {RequestId, stream_start, Headers}} ->
			erlang:display({http_stream_start, Headers}),
			ManagerName = manager:pid_name(Account),
			process_lib:find_send(ManagerName, {download_started, [{download, Download}]}),
			download(Account, Download, RequestId);
		{http, {RequestId, saved_to_file}} ->
			erlang:display({http_saved_to_file, RequestId}),
			NowFileSize = filelib:file_size(Download:file()),
			UpdatedDownload = Download:set(progress, NowFileSize),
			ManagerName = manager:pid_name(Account),
			process_lib:find_send(ManagerName, {download_complete, [{download, UpdatedDownload}]}),
			exit(UpdaterPid, kill);
		{http, {RequestId, {error, Reason}}} ->
			erlang:display({http_error, RequestId}),
			ManagerName = manager:pid_name(Account),
			process_lib:find_send(ManagerName, {download_error, [{download, Download}]}),
			exit(UpdaterPid, kill);
		Message ->
			erlang:display({message, Message}),
			download(Account, Download, UpdaterPid)
	end.

execute(Account, Download) ->
	HttpClient = http_client:instance(Account),
	case download_meta(HttpClient, Download) of
		{download, UpdatedDownload} ->
			Headers = [{"User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2490.80 Safari/537.36"},
				   {"Accept-Language", "en-US,en;q=0.8"}],
			case httpc:request(get, {UpdatedDownload:real_url(), Headers}, [], 
							   		[{sync, false}, 
									{stream, UpdatedDownload:file()}, 
									{receiver, self()}], HttpClient) of
				{ok, RequestId} ->
					UpdaterPid = spawn(download_updater, update_download, [Account, UpdatedDownload]),
					erlang:display({http_message, {ok, RequestId}}),
					download(Account, UpdatedDownload, UpdaterPid)
			end;
		{error, Errors} ->
			erlang:display({content_disposition, Download})
	end.