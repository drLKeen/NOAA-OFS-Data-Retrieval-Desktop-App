function result = plot_thredds_sst_axesm(datasetURL,requestedTime,targetAxes,progressCallback)
%PLOT_THREDDS_SST_AXESM Read one ROMS surface-temperature field using OPeNDAP.
% result = plot_thredds_sst_axesm(datasetURL,requestedTime) reads metadata, grid
% coordinates, land mask, and ONE temperature time/depth slice into memory.
% No NetCDF file is downloaded to disk. OPeNDAP still transfers the requested
% arrays over the network. Horizontal stride is one (native resolution).
% An optional third input draws into an existing axesm-based axes, including UIAxes.
%
% datasetURL must be the /thredds/dodsC/ URL, without .html, .dds or .das.
% requestedTime must be a scalar datetime with an explicit time zone.
% This reader supports ROMS rho-grid fields, not arbitrary NetCDF schemas.
% CBOFS temp is model potential temperature in its top water layer; this
% is near-surface model temperature, not satellite skin temperature.
%
% Catalog: https://opendap.co-ops.nos.noaa.gov/thredds/catalog/CBOFS/fmrc/catalog.html
arguments
    datasetURL (1,1) string
    requestedTime (1,1) datetime
    targetAxes = []
    progressCallback = []
end
assert(isempty(targetAxes) || (isscalar(targetAxes) && ...
    isa(targetAxes,"matlab.graphics.axis.AbstractAxes") && isvalid(targetAxes)), ...
    "targetAxes must be a valid scalar axes.");
assert(contains(datasetURL,"/thredds/dodsC/") && ...
    ~endsWith(datasetURL,[".html",".dds",".das"]), ...
    "Use the dataset's OPeNDAP URL, not its catalog or metadata page.");
assert(~isempty(requestedTime.TimeZone) && ~isnat(requestedTime), ...
    "requestedTime must have an explicit time zone and be a valid time.");
requestedTime.TimeZone = "UTC";
timer = tic;
phaseTimer = tic;
fprintf("Reading OPeNDAP metadata: %s\n",datasetURL);

% ncinfo returns dimensions in MATLAB order; never assume the order shown
% by the server's DDS (which is normally reversed relative to MATLAB).
thredds_request_checkpoint(progressCallback,"reading");
temperatureInfo = ncinfo(datasetURL,"temp");
thredds_request_checkpoint(progressCallback,"reading");
dimensionNames = string({temperatureInfo.Dimensions.Name});
timeDimension = find(ismember(dimensionNames,["time","ocean_time"]));
depthDimension = find(dimensionNames == "s_rho");
assert(isscalar(timeDimension) && isscalar(depthDimension), ...
    "Expected one time/ocean_time dimension and one ROMS s_rho dimension.");
timeVariable = dimensionNames(timeDimension);
timeInfo = ncinfo(datasetURL,timeVariable);
thredds_request_checkpoint(progressCallback,"reading");
times = decodeTime(ncread(datasetURL,timeVariable),timeInfo);
thredds_request_checkpoint(progressCallback,"reading");
assert(all(~isnat(times)) && ~isempty(times),"Invalid or empty time axis.");
assert(requestedTime >= min(times) && requestedTime <= max(times), ...
    "Requested time is outside this dataset (%s to %s UTC).", ...
    string(min(times)),string(max(times)));
[timeDifference,timeIndex] = min(abs(times-requestedTime));
assert(timeDifference <= hours(1), ...
    "No available time lies within one hour of the requested time.");
selectedTime = times(timeIndex);

% ROMS s_rho is negative below the surface and positive upward. The maximum
% coordinate identifies the top rho layer; it is not assumed to be index 1.
sigma = ncread(datasetURL,"s_rho");
thredds_request_checkpoint(progressCallback,"reading");
assert(all(isfinite(sigma)) && all(sigma <= 0 & sigma >= -1), ...
    "Expected ROMS s_rho coordinates between -1 and 0.");
[surfaceSigma,surfaceIndex] = max(sigma);
start = ones(1,numel(dimensionNames));
count = temperatureInfo.Size;
start(timeDimension) = timeIndex;
count(timeDimension) = 1;
start(depthDimension) = surfaceIndex;
count(depthDimension) = 1;

fprintf("Requested: %s UTC; selected: %s UTC\n", ...
    string(requestedTime),string(selectedTime));
fprintf("Reading top layer %d (s_rho = %.4f), one time only.\n", ...
    surfaceIndex,surfaceSigma);
timings.MetadataAndTime = toc(phaseTimer);
phaseTimer = tic;
% This hyperslab request is evaluated remotely by the OPeNDAP server.
temperature = ncread(datasetURL,"temp",start,count);
thredds_request_checkpoint(progressCallback,"reading");
timings.TemperatureRead = toc(phaseTimer);
phaseTimer = tic;
longitude = ncread(datasetURL,"lon_rho");
thredds_request_checkpoint(progressCallback,"reading");
latitude = ncread(datasetURL,"lat_rho");
thredds_request_checkpoint(progressCallback,"reading");
wet = ncread(datasetURL,"mask_rho") == 1;
thredds_request_checkpoint(progressCallback,"reading");

% Align temperature dimensions with lon_rho/lat_rho explicitly.
gridInfo = ncinfo(datasetURL,"lon_rho");
thredds_request_checkpoint(progressCallback,"reading");
timings.GridRead = toc(phaseTimer);
phaseTimer = tic;
gridDimensions = string({gridInfo.Dimensions.Name});
[present,gridOrder] = ismember(gridDimensions,dimensionNames);
assert(all(present) && numel(gridOrder)==2 && numel(dimensionNames)==4, ...
    "Expected two horizontal rho dimensions plus depth and time.");
temperature = permute(temperature,[gridOrder,depthDimension,timeDimension]);
temperature = reshape(temperature,size(longitude));
assert(isequal(size(temperature),size(latitude),size(wet)), ...
    "Temperature, coordinates and mask do not share the same grid.");
units = lower(string(attributeValue(temperatureInfo,"units","")));
if ismember(units,["kelvin","k"])
    temperature = temperature - 273.15;
else
    assert(ismember(units,["celsius","degree_celsius","degrees_celsius","degc"]), ...
        "Unrecognized temperature units: %s",units);
end
% ncread handles _FillValue, scale_factor and add_offset automatically.
temperature(~wet | ~isfinite(longitude) | ~isfinite(latitude)) = NaN;
assert(any(isfinite(temperature),"all"),"No valid ocean temperatures returned.");
readSeconds = toc(timer);
timings.PrepareField = toc(phaseTimer);
fprintf("Read complete in %.2f s: %d x %d grid, %.2f to %.2f deg C.\n", ...
    readSeconds,size(temperature,1),size(temperature,2), ...
    min(temperature,[],"all","omitnan"),max(temperature,[],"all","omitnan"));

% Render the native ROMS grid directly; no regular raster or geometry cache.
thredds_request_checkpoint(progressCallback,"rendering");
timings.Interpolation = 0;
phaseTimer = tic;
valid = isfinite(temperature);
latitudeLimits = [min(latitude(valid)),max(latitude(valid))];
longitudeLimits = [min(longitude(valid)),max(longitude(valid))];
displayLimits = [min(temperature(valid)),max(temperature(valid))];
if displayLimits(1) == displayLimits(2)
    displayLimits = displayLimits + [-0.5 0.5];
end
if isempty(targetAxes)
    fig = figure(Name="THREDDS native-grid temperature",Color="w");
    ax = axes(fig);
else
    ax = targetAxes;
    fig = ancestor(ax,"figure");
end
context = thredds_axesm_context(ax); %#ok<NASGU>
% Reinitialize for the selected OFS extent; this also resets old pan/zoom.
cla(ax,'reset');
axesm('mercator','MapLatLimit',latitudeLimits, ...
    'MapLonLimit',longitudeLimits,'Frame','on','Grid','on', ...
    'MeridianLabel','on','ParallelLabel','on');
axis(ax,'off');
h = pcolorm(latitude,longitude,temperature,'FaceColor','interp','EdgeColor','none');
landPatch = thredds_axesm_background(ax,latitudeLimits,longitudeLimits);
tightmap;
clim(ax,displayLimits);
colormap(ax,turbo(256));
cb = colorbar(ax);
cb.FontSize = 14;
cb.Label.FontSize = 14;
cb.Label.String = 'Temperature (deg C)';
title(ax,{'ROMS near-surface temperature',char(string(selectedTime)+' UTC')});
drawnow;
timings.Graphics = toc(phaseTimer);
timings.Total = toc(timer);
assert(isequaln(h.CData,temperature),'Native surface colors changed.');
result = struct(DatasetURL=datasetURL,RequestedTime=requestedTime, ...
    SelectedTime=selectedTime,TimeIndex=timeIndex,SurfaceIndex=surfaceIndex, ...
    SurfaceSigma=surfaceSigma,Longitude=longitude,Latitude=latitude, ...
    TemperatureC=temperature,WetMask=wet,ReadStart=start,ReadCount=count, ...
    ReadSeconds=readSeconds,Figure=fig,Axes=ax,Surface=h, ...
    LatitudeLimits=latitudeLimits,LongitudeLimits=longitudeLimits, ...
    Timings=timings,DisplayLimits=displayLimits, ...
    LandPatch=landPatch);
end
function value = attributeValue(info,name,defaultValue)
index = find(string({info.Attributes.Name}) == name,1);
if isempty(index)
    value = defaultValue;
else
    value = info.Attributes(index).Value;
end
end

function times = decodeTime(values,info)
% Decode common CF time units; reject calendars that datetime cannot model.
calendar = string(attributeValue(info,"calendar","standard"));
assert(ismember(calendar,["standard","gregorian","proleptic_gregorian"]), ...
    "Unsupported CF calendar: %s",calendar);
units = string(attributeValue(info,"units",""));
parts = regexp(units,"^(seconds|minutes|hours|days) since (.+)$","tokens","once");
assert(~isempty(parts),"Unsupported time units: %s",units);
originText = regexprep(string(parts{2}),"\s*(UTC|Z)$","");
originText = replace(originText,"T"," ");
origin = datetime(originText,TimeZone="UTC");
switch string(parts{1})
    case "seconds", offset = seconds(values);
    case "minutes", offset = minutes(values);
    case "hours", offset = hours(values);
    case "days", offset = days(values);
end
times = origin + offset(:);
times.Format = "yyyy-MM-dd HH:mm:ss";
end


