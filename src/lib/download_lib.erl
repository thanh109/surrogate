%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% FILE: download_lib.erl
%
% AUTHOR: Jake Breindel
% DATE: 5-25-15
%
% DESCRIPTION:
%
% Download library
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-module(download_lib).
-compile(export_all).
-include("download_status.hrl").

save_downloads(Premium, Links) ->
	save_downloads(Premium, Links, []).

save_downloads(Premium, [], SavedDls) ->
	{ok, SavedDls};
save_downloads(Premium, [Link|Links], SavedDls) ->
	RealUrl = "",
	File = "",
	Length = 0,
	Progress = 0,
	CreatedTime = os:timestamp(),
	Download = download:new(id, Link, RealUrl, ?DL_PENDING, File, Length, Progress, CreatedTime, Premium:id()),
	case Download:save() of
		{ok, SavedDownload} ->
			SavedDlList = SavedDls ++ [SavedDownload],
    		save_downloads(Premium, Links, SavedDlList);				
		{error, Errors} ->
			{error, Errors}
	end.

download_completed(CompletedDownload) ->
	Id = CompletedDownload:id(),
	case boss_db:find(Id) of
		{error, Error} ->
			false;
		Download ->
			Download:length() == CompletedDownload:progress()
	end.

add_chunk_property(DownloadProps, JsonProps) ->
	case proplists:get_value(chunk_size, DownloadProps) of
		undefined ->
			JsonProps;
		ChunkSize ->
			JsonProps ++ [{chunk_size, ChunkSize}]
	end.

add_speed_property(DownloadProps, JsonProps) ->
	case proplists:get_value(speed, DownloadProps) of
		undefined ->
			JsonProps;
		Speed ->
			JsonProps ++ [{speed, Speed}]
	end.

add_meta_properties(DownloadProps, JsonProps) ->
	ChunkProps = add_chunk_property(DownloadProps, JsonProps),
	add_speed_property(DownloadProps, ChunkProps).

download_to_json(DownloadProps) ->
	case proplists:get_value(download, DownloadProps) of
		undefined ->
			{struct, []};
		Download ->
			case boss_model_manager:to_json(Download) of
				{struct, JsonProps} ->
					{struct, add_meta_properties(DownloadProps, JsonProps)};
				_ ->
					{struct, []}
			end
	end.
