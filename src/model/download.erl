%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% FILE: download.erl
%
% AUTHOR: Jake Breindel
% DATE: 5-20-15
%
% DESCRIPTION:
%
% Model class for a download
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-module(download, [Id, DisplayUrl::string(), RealUrl::string(), Status::integer(), File::string(), Length::integer(), Progress::integer(), PremiumId::integer()]).
-compile(export_all).
-belongs_to(premium).
