function spec = thredds_field_spec(dataType)
% Field names and display conventions for the supported ROMS systems.
spec = struct('DataType',string(dataType),'Variables',strings(0), ...
    'Units',"",'Label',"",'Description',"",'IsVector',false);
switch string(dataType)
    case "Temperature"
        spec.Variables="temp"; spec.Units="deg C";
        spec.Description="Top-layer model potential temperature";
    case "Salinity"
        spec.Variables="salt"; spec.Units="PSU";
        spec.Description="Top-layer model practical salinity";
    case "Water level"
        spec.Variables="zeta"; spec.Units="meters";
        spec.Description="Model free-surface elevation relative to the model datum";
    case "Wind"
        spec.Variables=["Uwind","Vwind"]; spec.Units="m/s";
        spec.Description="Surface wind (m/s); arrows point toward flow";
        spec.IsVector=true;
    case "Currents"
        spec.Variables=["u","v"]; spec.Units="m/s";
        spec.Description="Top-layer currents (m/s); arrows point toward flow";
        spec.IsVector=true;
    otherwise
        error('THREDDS:DataType','Unknown data type: %s',dataType);
end
spec.Label=spec.DataType+" ("+spec.Units+")";
end
