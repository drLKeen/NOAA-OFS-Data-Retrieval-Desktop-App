function folder = export_thredds_result(result,ax,parentFolder,packageName,mode,resolution)
%export_thredds_result Export a loaded THREDDS map and native data.
%   FOLDER = export_thredds_result(R,AX,PARENT,NAME,MODE,DPI) creates a new
%   export folder. MODE is "Map + data", "Map only", or "Data only".
%   Maps are PNG images of the current axes. MAT-files contain a plain
%   data struct with the full native grid. JSON records provenance and
%   display settings. No remote data are read and no files are overwritten.
%
%   See also exportgraphics, save, writestruct

mode=string(mode); packageName=string(packageName);
assert(ismember(mode,["Map + data","Map only","Data only"]), ...
    'THREDDS:ExportMode','Choose a valid export option.');
assert(isscalar(packageName) && strlength(strtrim(packageName))>0 && ...
    isempty(regexp(char(packageName),'[<>:"/\\|?*\x00-\x1F]','once')) && ...
    ~endsWith(packageName,["."," "]) && ...
    isempty(regexpi(char(packageName),'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)','once')), ...
    'THREDDS:ExportName','Enter a folder name without reserved characters or names.');
assert(isfolder(parentFolder),'THREDDS:ExportFolder','Choose an existing destination folder.');
assert(isnumeric(resolution) && isscalar(resolution) && isfinite(resolution) && ...
    resolution>=72 && resolution<=1200,'THREDDS:ExportResolution','Resolution must be 72–1200 dpi.');
assert(isstruct(result),'THREDDS:ExportData','Load a field before exporting.');
if ~isfield(result,'Values') && isfield(result,'TemperatureC')
    result.Values=result.TemperatureC;
    result.DataType="Temperature"; result.Spec=thredds_field_spec('Temperature');
end
assert(isfield(result,'Values') && ~isempty(result.Values), ...
    'THREDDS:ExportData','Load a field before exporting.');
assert(isgraphics(ax),'THREDDS:ExportAxes','The map is no longer available.');
if result.Spec.IsVector
    assert(~isempty(result.Arrows) && all(isgraphics(result.Arrows)) && ...
        all(arrayfun(@(h)isequal(h.Parent,ax),result.Arrows)) && ...
        isequaln(get(result.Arrows,{'XData'}),result.VectorDisplay.XData) && ...
        isequaln(get(result.Arrows,{'YData'}),result.VectorDisplay.YData), ...
        'THREDDS:ExportMismatch','The displayed vectors no longer match the loaded data.');
else
assert(isfield(result,'Surface') && isgraphics(result.Surface) && ...
    isequal(result.Surface.Parent,ax) && ...
    isequaln(result.Surface.CData,result.Values), ...
    'THREDDS:ExportMismatch','The displayed field no longer matches the loaded data. Reload before exporting.');
end
permissions=filePermissions(parentFolder);
parentFolder=string(permissions.AbsolutePath);
folder=fullfile(parentFolder,packageName);
suffix=2;
while isfolder(folder) || isfile(folder)
    folder=fullfile(parentFolder,packageName+sprintf('_%03d',suffix));
    suffix=suffix+1;
end
metadata=struct;
metadata.ExportedUTC=utcText(datetime('now','TimeZone','UTC'));
metadata.System=string(result.System);
metadata.Product=string(result.Product);
metadata.DatasetURL=string(result.DatasetURL);
metadata.RequestedTimeUTC=utcText(result.RequestedTime);
metadata.SelectedTimeUTC=utcText(result.SelectedTime);
metadata.DataType=result.DataType;
metadata.Variable=result.Spec.Variables;
metadata.Description=result.Spec.Description;
metadata.Units=struct('Values',result.Spec.Units, ...
    'Latitude',"degrees_north",'Longitude',"degrees_east");
if result.DataType=="Temperature", metadata.Units.TemperatureC="degrees_Celsius"; end
metadata.SurfaceIndex=result.SurfaceIndex;
metadata.SurfaceSigma=result.SurfaceSigma;
metadata.TimeIndex=result.TimeIndex;
metadata.ReadStart=result.ReadStart;
metadata.ReadCount=result.ReadCount;
metadata.DataScope="Full loaded native grid, regardless of map zoom";
metadata.NativeGridSize=size(result.Values);
metadata.ValuesClass=string(class(result.Values));
if result.DataType=="Temperature", metadata.TemperatureClass=string(class(result.Values)); end
if isfield(result,'ReadSlices'), metadata.ReadSlices=result.ReadSlices; end
if result.Spec.IsVector
    metadata.Units.Eastward="m/s"; metadata.Units.Northward="m/s";
    metadata.VectorProcessing="Grid-relative components rotated using angle; staggered currents averaged to rho points, nearest face at domain edges, missing faces propagated";
    metadata.VectorDisplay=struct('Spacing',result.VectorDisplay.Spacing, ...
        'Count',numel(result.VectorDisplay.Indices),'ScaleSeconds',result.VectorDisplay.ScaleSeconds);
end
metadata.MissingValues="NaN; WetMask identifies native wet cells";
metadata.NativeLatitudeLimits=result.LatitudeLimits;
metadata.NativeLongitudeLimits=result.LongitudeLimits;
metadata.ForecastRun="Not separately resolved; see DatasetURL and selected valid time";
metadata.ExportMode=mode;
metadata.MapResolutionDPI=resolution;
metadata.MATLABVersion=string(version);
projection=getm(ax);
palette=colormap(ax);
metadata.Map=struct('Projection',string(projection.mapprojection), ...
    'XLim',ax.XLim,'YLim',ax.YLim,'MapLatitudeLimits',projection.maplatlimit, ...
    'MapLongitudeLimits',projection.maplonlimit,'ColorLimits',ax.CLim, ...
    'ColormapRGB',struct('Red',palette(:,1)','Green',palette(:,2)', ...
    'Blue',palette(:,3)'),'Title',string(ax.Title.String), ...
    'Subtitle',string(ax.Subtitle.String),'Grid',string(projection.grid), ...
    'MeridianSpacing',projection.mlinelocation,'ParallelSpacing',projection.plinelocation, ...
    'GridColorRGB',projection.gcolor,'GridLineStyle',string(projection.glinestyle), ...
    'GridLineWidth',projection.glinewidth, ...
    'LandVisible',false,'LandColorRGB',[],'LandAlpha',[]);
land=findobj(ax,'Tag','THREDDSLand');
if ~isempty(land)
    metadata.Map.LandVisible=strcmp(land(1).Visible,'on');
    metadata.Map.LandColorRGB=land(1).FaceColor;
    metadata.Map.LandAlpha=land(1).FaceAlpha;
end
metadata.Files=struct('Map',"",'Data',"",'Metadata',"metadata.json");
if mode~="Data only", metadata.Files.Map=packageName+".png"; end
if mode~="Map only", metadata.Files.Data=packageName+".mat"; end
[ok,message]=mkdir(folder);
assert(ok,'THREDDS:ExportFolder','Cannot create export folder: %s',message);
created=strings(0,1);
try
if mode~="Data only"
    created(end+1)=fullfile(folder,metadata.Files.Map);
    exportgraphics(ax,created(end),'Resolution',resolution);
end
if mode~="Map only"
    data=struct('Values',result.Values,'DataType',result.DataType,'Latitude',result.Latitude, ...
        'Longitude',result.Longitude,'WetMask',result.WetMask, ...
        'RequestedTime',result.RequestedTime,'SelectedTime',result.SelectedTime, ...
        'Metadata',metadata);
    if result.DataType=="Temperature", data.TemperatureC=result.Values; end
    if isfield(result,'Native')
        data.Native=result.Native;
        data.VariableAttributes=result.VariableAttributes;
    end
    if result.Spec.IsVector
        data.Eastward=result.Eastward; data.Northward=result.Northward;
        data.GridAngle=result.GridAngle;
    end
    created(end+1)=fullfile(folder,metadata.Files.Data);
    details=whos('data');
    if details.bytes>1.8e9
        save(created(end),'data','-v7.3');
    else
        save(created(end),'data','-v7');
    end
end
created(end+1)=fullfile(folder,'metadata.json');
writestruct(metadata,created(end));
catch exception
    rollback();
    rethrow(exception)
end

    function rollback()
        for file=created'
            if isfile(file), delete(file); end
        end
        % Only remove the new folder if empty; never remove other content.
        if isfolder(folder), rmdir(folder); end
    end
end

function text = utcText(t)
t.TimeZone='UTC';
text=string(t,'yyyy-MM-dd''T''HH:mm:ss''Z''');
end
