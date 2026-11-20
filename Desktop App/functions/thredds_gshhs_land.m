function land = thredds_gshhs_land(filename,latlim,lonlim)
%thredds_gshhs_land Read filled land polygons from GMT GSHHS NetCDF.
%   LAND = thredds_gshhs_land(FILENAME,LATLIM,LONLIM) reconstructs land
%   and lake holes in bins intersecting the specified region. LAND is a
%   polyshape with longitude as x and latitude as y. No source vertices
%   are thinned. This regional reader excludes Antarctica and the poles.
%
%   See also thredds_gshhs_bin_land, polyshape, patchm

assert(latlim(1)>-60 && latlim(2)<90 && diff(latlim)>0 && ...
    diff(lonlim)>0 && diff(lonlim)<180,'Expected a regional OFS extent.');
ncid = netcdf.open(filename,'NOWRITE');
cleanup = onCleanup(@()netcdf.close(ncid));
binSize = double(readVariable('Bin_size_in_minutes'))/60;
nx = double(readVariable('N_bins_in_360_longitude_range'));
firstSegment = double(readVariable('Id_of_first_segment_in_a_bin'));
segmentCount = double(readVariable('N_segments_in_a_bin'));
nodeLevels = readVariable('Embedded_node_levels_in_a_bin');
binId = (0:numel(segmentCount)-1)';
south = 90-(floor(binId/nx)+1)*binSize;
west = mod(binId,nx)*binSize;
west = west+360*floor((mean(lonlim)-west)/360);
west(west+binSize<lonlim(1)) = west(west+binSize<lonlim(1))+360;
bins = find(south<latlim(2) & south+binSize>latlim(1) & ...
    west<lonlim(2) & west+binSize>lonlim(1));
infoId = netcdf.inqVarID(ncid,'Embedded_npts_levels_exit_entry_for_a_segment');
startId = netcdf.inqVarID(ncid,'Id_of_first_point_in_a_segment');
xId = netcdf.inqVarID(ncid,'Relative_longitude_from_SW_corner_of_bin');
yId = netcdf.inqVarID(ncid,'Relative_latitude_from_SW_corner_of_bin');
tiles = repmat(polyshape,numel(bins),1);
for k = 1:numel(bins)
    b = bins(k);
    packed = zeros(0,1,'int32');
    starts = zeros(0,1);
    if segmentCount(b)>0
        packed = netcdf.getVar(ncid,infoId,firstSegment(b),segmentCount(b));
        starts = double(netcdf.getVar(ncid,startId,firstSegment(b),segmentCount(b)));
    end
    counts = double(bitshift(packed,-9));
    levels = double(bitand(bitshift(packed,-6),7));
    entry = double(bitand(bitshift(packed,-3),7));
    exitSide = double(bitand(packed,7));
    segments = cell(numel(starts),1);
    if ~isempty(starts)
        first = min(starts);
        count = max(starts+counts)-first;
        dx = double(typecast(netcdf.getVar(ncid,xId,first,count),'uint16'));
        dy = double(typecast(netcdf.getVar(ncid,yId,first,count),'uint16'));
        for s = 1:numel(starts)
            indices = starts(s)-first+(1:counts(s));
            segments{s} = [dx(indices(:)),dy(indices(:))]/65535;
        end
    end
    corners = double(bitand(bitshift(nodeLevels(b),-[9 6 3 0]),7));
    tile = thredds_gshhs_bin_land(segments,levels,entry,exitSide,corners);
    tiles(k) = translate(scale(tile,binSize),[west(b) south(b)]);
end
land = union(tiles,'KeepCollinearPoints',true);
clip = polyshape(lonlim([1 2 2 1]),latlim([1 1 2 2]));
land = intersect(land,clip,'KeepCollinearPoints',true);

    function value = readVariable(name)
        value = netcdf.getVar(ncid,netcdf.inqVarID(ncid,name));
    end
end
