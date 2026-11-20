function source = resolve_thredds_dataset(systemName,product,requestedTime,progressCallback)
%RESOLVE_THREDDS_DATASET Find a published OFS temperature dataset in THREDDS.
% Forecast uses the catalog's Best Time Series. Nowcast chooses an individual
% ROMS field, verifies its actual time, and never substitutes forecast data.
arguments
    systemName (1,1) string {mustBeMember(systemName,["CBOFS","CIOFS","DBOFS","GOMOFS","TBOFS","NYOFS"])}
    product (1,1) string {mustBeMember(product,["Forecast","Nowcast"])}
    requestedTime (1,1) datetime
    progressCallback = []
end
assert(~isnat(requestedTime) && ~isempty(requestedTime.TimeZone), ...
    'THREDDS:InvalidTime','Choose a valid UTC time.');
requestedTime.TimeZone = 'UTC';
assert(systemName ~= "NYOFS",'THREDDS:TemperatureUnavailable', ...
    'NOAA lists NYOFS, but its published forecast and nowcast fields do not include temperature. Choose another OFS for this temperature map.');
host = "https://opendap.co-ops.nos.noaa.gov";
source = struct(System=systemName,Product=product,RequestedTime=requestedTime, ...
    SelectedTime=requestedTime,DatasetURL="");
if product == "Forecast"
    thredds_request_checkpoint(progressCallback,"catalog");
    paths = catalogPaths(host+"/thredds/catalog/"+systemName+"/fmrc/catalog.xml");
    thredds_request_checkpoint(progressCallback,"catalog");
    paths = paths(endsWith(paths,"_best.ncd"));
    assert(isscalar(paths),'THREDDS:ForecastUnavailable', ...
        'No unique forecast Best Time Series is published for %s.',systemName);
    source.DatasetURL = host+"/thredds/dodsC/"+paths;
    return
end

% A 00 UTC run contains nowcasts from the previous evening, so inspect both
% the requested calendar day and the following day's catalog.
paths = strings(0,1);
day = dateshift(requestedTime,'start','day');
for offset = 0:1
    thredds_request_checkpoint(progressCallback,"catalog");
    catalogURL = host+"/thredds/catalog/NOAA/"+systemName+"/MODELS/"+ ...
        string(day+caldays(offset),'yyyy/MM/dd')+"/catalog.xml";
    try
        paths = [paths; catalogPaths(catalogURL)]; %#ok<AGROW>
    catch exception
        if ~contains(exception.message,'404')
            rethrow(exception)
        end
    end
end
thredds_request_checkpoint(progressCallback,"catalog");
paths = unique(paths(contains(paths,'.fields.n')));
assert(~isempty(paths),'THREDDS:NowcastUnavailable', ...
    'No nowcast fields are published for this date. The run may not be available yet, or the date may be outside archive retention.');

% These five ROMS systems publish six-hour nowcast cycles: n006 is the cycle
% time, n003 is three hours earlier, etc. GOMOFS publishes every three hours.
% Use names only to shortlist; verify the selected file against CF time.
times = thredds_nowcast_times(paths);
[distance,order] = sort(abs(times-requestedTime));
candidates = order(distance <= hours(1));
validTimes = times(~isnat(times));
assert(~isempty(validTimes),'THREDDS:NowcastNaming', ...
    'The nowcast catalog uses an unrecognized file naming scheme.');
assert(~isempty(candidates),'THREDDS:NowcastTimeUnavailable', ...
    'No published nowcast is within one hour of %s UTC. Available fields in these daily catalogs span %s to %s UTC.', ...
    string(requestedTime),string(min(validTimes)),string(max(validTimes)));
for k = candidates(:)'
    thredds_request_checkpoint(progressCallback,"catalog");
    url = host+"/thredds/dodsC/"+paths(k);
    info = ncinfo(url,'ocean_time');
    thredds_request_checkpoint(progressCallback,"catalog");
    actualTime = decodeCFTime(ncread(url,'ocean_time'),info);
    thredds_request_checkpoint(progressCallback,"catalog");
    assert(isscalar(actualTime) && abs(actualTime-times(k)) < seconds(1), ...
        'THREDDS:NowcastTimeMismatch','The nowcast file time does not match its catalog name.');
    if abs(actualTime-requestedTime) <= hours(1)
        source.DatasetURL = url;
        source.SelectedTime = actualTime;
        return
    end
end
error('THREDDS:NowcastTimeUnavailable','No nowcast time matches the request within one hour.');
end

function paths = catalogPaths(url)
xml = webread(url,weboptions(Timeout=20,ContentType='text'));
document = parseString(matlab.io.xml.dom.Parser,xml);
nodes = getElementsByTagName(document,'dataset');
paths = strings(nodes.Length,1);
for k = 1:nodes.Length
    paths(k) = string(getAttribute(item(nodes,k-1),'urlPath'));
end
paths = paths(strlength(paths)>0);
end

function times = decodeCFTime(values,info)
attributes = string({info.Attributes.Name});
calendarIndex = find(attributes == "calendar",1);
if ~isempty(calendarIndex)
    assert(ismember(string(info.Attributes(calendarIndex).Value), ...
        ["standard","gregorian","proleptic_gregorian"]), ...
        'THREDDS:Calendar','Unsupported nowcast calendar.');
end
unitsIndex = find(attributes == "units",1);
assert(~isempty(unitsIndex),'THREDDS:TimeUnits','Missing nowcast time units.');
parts = regexp(string(info.Attributes(unitsIndex).Value), ...
    '^(seconds|minutes|hours|days) since (.+)$','tokens','once');
assert(~isempty(parts),'THREDDS:TimeUnits','Unsupported nowcast time units.');
origin = datetime(replace(regexprep(string(parts{2}),'\s*(UTC|Z)$',''),'T',' '),TimeZone='UTC');
switch string(parts{1})
    case "seconds", times = origin+seconds(values);
    case "minutes", times = origin+minutes(values);
    case "hours", times = origin+hours(values);
    case "days", times = origin+days(values);
end
end

