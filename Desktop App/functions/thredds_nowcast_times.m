function times = thredds_nowcast_times(paths)
%thredds_nowcast_times Decode advertised ROMS nowcast times from filenames.
%   T = thredds_nowcast_times(PATHS) returns UTC timestamps, or NaT for
%   unrecognized names. File contents must still be verified before use.
%
%   See also resolve_thredds_dataset

paths=string(paths);
times=NaT(size(paths),'TimeZone','UTC');
for k=1:numel(paths)
    token=regexp(paths(k),'\.t(\d{2})z\.(\d{8})\.fields\.n(\d{3})\.nc$', ...
        'tokens','once');
    if ~isempty(token)
        cycle=datetime(token{2},'InputFormat','yyyyMMdd','TimeZone','UTC')+hours(str2double(token{1}));
        times(k)=cycle+hours(str2double(token{3})-6);
    end
end
end
