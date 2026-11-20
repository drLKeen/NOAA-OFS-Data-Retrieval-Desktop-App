function listing = thredds_data_availability(systemName,product,day,progressCallback,dataType)
%thredds_data_availability Query published forecast or nowcast timestamps.
%   S = thredds_data_availability(OFS,PRODUCT,DAY,CALLBACK) reads forecast
%   time coordinates, or nowcast filenames for DAY and the following day.
%   S.Times contains UTC times. Nowcast times are advertised, with actual
%   file timestamps verified by the resolver on Load. No fields are read.
%
%   See also resolve_thredds_dataset, thredds_nowcast_times

if nargin<4, progressCallback=[]; end
if nargin<5, dataType="Temperature"; end
spec=thredds_field_spec(dataType);
systemName=string(systemName); product=string(product);
assert(ismember(systemName,["CBOFS","CIOFS","DBOFS","GOMOFS","TBOFS","NYOFS"]));
assert(ismember(product,["Forecast","Nowcast"]));
assert(isscalar(day) && ~isnat(day) && ~isempty(day.TimeZone));
assert(systemName~="NYOFS",'THREDDS:TemperatureUnavailable', ...
    'Temperature is not available in published NYOFS fields.');
day.TimeZone='UTC'; day=dateshift(day,'start','day');
listing=struct('System',systemName,'Product',product,'Day',day, ...
    'DatasetURL',"",'Times',NaT(0,1,'TimeZone','UTC'),'CheckedAt',NaT('TimeZone','UTC'));
if product=="Forecast"
    source=resolve_thredds_dataset(systemName,product,day,progressCallback);
    listing.DatasetURL=source.DatasetURL;
    listing.Times=readForecastTimes(source.DatasetURL,progressCallback,spec.Variables(1));
else
    paths=strings(0,1);
    for offset=0:1
        thredds_request_checkpoint(progressCallback,"availability");
        url="https://opendap.co-ops.nos.noaa.gov/thredds/catalog/NOAA/"+ ...
            systemName+"/MODELS/"+string(day+caldays(offset),'yyyy/MM/dd')+"/catalog.xml";
        try
            xml=webread(url,weboptions('Timeout',20,'ContentType','text'));
            document=parseString(matlab.io.xml.dom.Parser,xml);
            nodes=getElementsByTagName(document,'dataset');
            found=strings(nodes.Length,1);
            for k=1:nodes.Length
                found(k)=string(getAttribute(item(nodes,k-1),'urlPath'));
            end
            paths=[paths;found(contains(found,'.fields.n'))]; %#ok<AGROW>
        catch exception
            if ~contains(exception.message,'404'), rethrow(exception), end
        end
        thredds_request_checkpoint(progressCallback,"availability");
    end
    paths=unique(paths);
    times=thredds_nowcast_times(paths);
    assert(isempty(paths) || all(~isnat(times)),'THREDDS:NowcastNaming', ...
        'The nowcast catalog uses an unrecognized file naming scheme.');
    listing.Times=unique(times(times>=day & times<day+caldays(1)));
end
thredds_request_checkpoint(progressCallback,"availability");
listing.CheckedAt=datetime('now','TimeZone','UTC');
end

function times = readForecastTimes(url,callback,variable)
thredds_request_checkpoint(callback,"availability");
ncid=netcdf.open(url,'NOWRITE');
cleanup=onCleanup(@()netcdf.close(ncid));
thredds_request_checkpoint(callback,"availability");
tempid=netcdf.inqVarID(ncid,variable);
[~,~,dimids]=netcdf.inqVar(ncid,tempid);
names=strings(size(dimids));
for k=1:numel(dimids), names(k)=string(netcdf.inqDim(ncid,dimids(k))); end
timeName=names(ismember(names,["time","ocean_time"]));
assert(isscalar(timeName),'THREDDS:TimeUnits','Expected one time coordinate.');
varid=netcdf.inqVarID(ncid,timeName);
[~,~,~,natts]=netcdf.inqVar(ncid,varid);
attrs=struct;
for k=0:natts-1
    name=netcdf.inqAttName(ncid,varid,k);
    attrs.(matlab.lang.makeValidName(name))=netcdf.getAtt(ncid,varid,name);
end
values=double(netcdf.getVar(ncid,varid));
thredds_request_checkpoint(callback,"availability");
if isfield(attrs,'x_FillValue'), values(values==double(attrs.x_FillValue))=NaN; end
if isfield(attrs,'scale_factor'), values=values*double(attrs.scale_factor); end
if isfield(attrs,'add_offset'), values=values+double(attrs.add_offset); end
assert(~isempty(values) && all(isfinite(values)),'THREDDS:TimeUnits','Invalid time coordinate.');
if isfield(attrs,'calendar')
    assert(ismember(string(attrs.calendar),["standard","gregorian","proleptic_gregorian"]), ...
        'THREDDS:Calendar','Unsupported forecast calendar.');
end
assert(isfield(attrs,'units'),'THREDDS:TimeUnits','Missing forecast time units.');
parts=regexp(string(attrs.units),'^(seconds|minutes|hours|days) since (.+)$','tokens','once');
assert(~isempty(parts),'THREDDS:TimeUnits','Unsupported forecast time units.');
origin=datetime(replace(regexprep(string(parts{2}),'\s*(UTC|Z)$',''),'T',' '),'TimeZone','UTC');
switch string(parts{1})
    case "seconds", offset=seconds(values);
    case "minutes", offset=minutes(values);
    case "hours", offset=hours(values);
    case "days", offset=days(values);
end
times=unique(origin+offset(:));
assert(all(~isnat(times)),'THREDDS:TimeUnits','Invalid forecast dates.');
end
