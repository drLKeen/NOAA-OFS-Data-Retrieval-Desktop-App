function result = read_thredds_field(url,requestedTime,dataType,callback)
% Read one time and, where present, one surface layer of a ROMS field.
if nargin<4, callback=[]; end
spec=thredds_field_spec(dataType);
timer=tic;
checkpoint(); info=ncinfo(url); checkpoint();
names=string({info.Variables.Name});
assert(all(ismember([spec.Variables,"lon_rho","lat_rho","mask_rho"],names)), ...
    'THREDDS:FieldUnavailable','%s is not available in this supported ROMS schema.',dataType);
primary=variable(spec.Variables(1));
dims=string({primary.Dimensions.Name});
timeName=dims(ismember(dims,["time","ocean_time"]));
assert(isscalar(timeName),'THREDDS:TimeUnits','Expected one field time coordinate.');
timeInfo=variable(timeName); times=decodeTime(read(timeName),timeInfo);
assert(~isempty(requestedTime.TimeZone) && ~isnat(requestedTime));
requestedTime.TimeZone='UTC';
assert(requestedTime>=min(times) && requestedTime<=max(times), ...
    'THREDDS:TimeRange','Requested time is outside this field dataset.');
[distance,timeIndex]=min(abs(times-requestedTime));
assert(distance<=hours(1),'THREDDS:TimeRange','No field within one hour.');
surfaceIndex=[]; surfaceSigma=[];
if any(dims=="s_rho")
    sigma=read('s_rho');
    assert(all(isfinite(sigma)) && all(sigma>=-1 & sigma<=0));
    [surfaceSigma,surfaceIndex]=max(sigma);
end
lon=read('lon_rho'); lat=read('lat_rho'); wet=read('mask_rho')==1;
gridDims=string({variable('lon_rho').Dimensions.Name});
assert(isequal(gridDims,["xi_rho","eta_rho"]), ...
    'THREDDS:GridOrder','Expected xi, eta order for the ROMS grid.');
native=struct; slices=struct; attrs=struct;
for name=spec.Variables
    vi=variable(name); dn=string({vi.Dimensions.Name});
    start=ones(1,numel(dn)); count=vi.Size;
    td=find(dn==timeName); assert(isscalar(td));
    start(td)=timeIndex; count(td)=1;
    zd=find(dn=="s_rho");
    if ~isempty(zd), start(zd)=surfaceIndex; count(zd)=1; end
    checkpoint(); values=ncread(url,name,start,count); checkpoint();
    values=missing(values,vi);
    horizontal=~ismember(dn,[timeName,"s_rho"]);
    assert(nnz(horizontal)==2 && startsWith(dn(1),"xi_") && startsWith(dn(2),"eta_"), ...
        'THREDDS:GridOrder','Unsupported horizontal dimension order.');
    native.(name)=reshape(values,count(horizontal));
    slices.(name)=struct('Start',start,'Count',count);
    attrs.(name)=vi.Attributes;
end
angle=[]; east=[]; north=[];
if spec.IsVector
    angle=read('angle');
    assert(string(attribute(variable('angle'),'units',""))=="radians", ...
        'THREDDS:VectorUnits','Expected grid angle in radians.');
    u=native.(spec.Variables(1)); v=native.(spec.Variables(2));
    assert(ismember(string(attribute(primary,'standard_name',"")), ...
        ["grid_eastward_sea_water_velocity","grid_eastward_wind", ...
        "sea_water_x_velocity","surface_x_wind"]), ...
        'THREDDS:VectorFrame','Expected grid-relative vector components.');
    assert(ismember(string(attribute(variable(spec.Variables(2)),'standard_name',"")), ...
        ["grid_northward_sea_water_velocity","grid_northward_wind", ...
        "sea_water_y_velocity","surface_y_wind"]), ...
        'THREDDS:VectorFrame','Expected grid-relative northward component.');
    for name=spec.Variables
        assert(ismember(string(attribute(variable(name),'units',"")), ...
            ["meter second-1","m/s","m s-1"]),'THREDDS:VectorUnits','Unexpected velocity units.');
    end
    if dataType=="Currents"
        native.mask_u=read('mask_u'); native.mask_v=read('mask_v');
        u(native.mask_u~=1)=NaN; v(native.mask_v~=1)=NaN;
        native.lon_u=read('lon_u'); native.lat_u=read('lat_u');
        native.lon_v=read('lon_v'); native.lat_v=read('lat_v');
    end
    [east,north]=thredds_rotate_vectors(u,v,angle,wet);
    values=hypot(east,north);
else
    values=native.(spec.Variables);
    unit=string(attribute(primary,'units',""));
    if dataType=="Temperature"
        assert(ismember(lower(unit),["celsius","degree_celsius","degrees_celsius","degc"]), ...
            'THREDDS:Units','Unexpected temperature units: %s',unit);
    elseif dataType=="Water level"
        assert(ismember(unit,["meter","meters","m"]),'THREDDS:Units','Unexpected water-level units.');
    elseif strlength(unit)>0
        spec.Units=unit; spec.Label=spec.DataType+" ("+unit+")";
        spec.Description="Top-layer model salinity";
    end
end
assert(isequal(size(values),size(lon),size(lat),size(wet)));
values(~wet | ~isfinite(lon) | ~isfinite(lat))=NaN;
if spec.IsVector
    east(~isfinite(values))=NaN; north(~isfinite(values))=NaN;
end
valid=isfinite(values); assert(any(valid,'all'),'THREDDS:EmptyField','No valid field values.');
limits=[min(values(valid)),max(values(valid))];
if limits(1)==limits(2), limits=limits+[-0.5 0.5]; end
result=struct('DatasetURL',string(url),'RequestedTime',requestedTime, ...
    'SelectedTime',times(timeIndex),'TimeIndex',timeIndex, ...
    'SurfaceIndex',surfaceIndex,'SurfaceSigma',surfaceSigma, ...
    'DataType',spec.DataType,'Spec',spec,'Values',values,'Latitude',lat, ...
    'Longitude',lon,'WetMask',wet,'Native',native,'VariableAttributes',attrs, ...
    'GridAngle',angle,'Eastward',east,'Northward',north,'ReadSlices',slices, ...
    'ReadStart',slices.(spec.Variables(1)).Start,'ReadCount',slices.(spec.Variables(1)).Count, ...
    'LatitudeLimits',[min(lat(valid)),max(lat(valid))], ...
    'LongitudeLimits',[min(lon(valid)),max(lon(valid))], ...
    'DisplayLimits',limits,'ReadSeconds',toc(timer));
if dataType=="Temperature", result.TemperatureC=values; end

    function vi=variable(name)
        vi=info.Variables(names==string(name));
        assert(isscalar(vi),'THREDDS:FieldUnavailable','Missing variable %s.',name);
    end
    function values=read(name)
        checkpoint(); values=ncread(url,name); checkpoint();
        values=missing(values,variable(name));
    end
    function checkpoint()
        thredds_request_checkpoint(callback,'reading');
    end
end

function values=missing(values,info)
fill=attribute(info,'missing_value',[]);
for k=1:numel(fill), values(values==fill(k))=NaN; end
end

function value=attribute(info,name,default)
i=find(strcmp({info.Attributes.Name},name),1);
if isempty(i), value=default; else, value=info.Attributes(i).Value; end
end

function times=decodeTime(values,info)
assert(ismember(string(attribute(info,'calendar','standard')), ...
    ["standard","gregorian","proleptic_gregorian"]));
parts=regexp(string(attribute(info,'units',"")), ...
    '^(seconds|minutes|hours|days) since (.+)$','tokens','once');
assert(~isempty(parts),'THREDDS:TimeUnits','Unsupported time units.');
origin=datetime(replace(regexprep(string(parts{2}),'\s*(UTC|Z)$',''),'T',' '),'TimeZone','UTC');
switch string(parts{1})
    case "seconds", offset=seconds(values);
    case "minutes", offset=minutes(values);
    case "hours", offset=hours(values);
    case "days", offset=days(values);
end
times=origin+offset(:); assert(all(~isnat(times)));
end
