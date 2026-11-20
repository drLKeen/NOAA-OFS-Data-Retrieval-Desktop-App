function [arrows,display] = thredds_draw_vectors(ax,result,spacing)
% Draw selected rho-grid vectors; zero spacing selects readable spacing.
context=thredds_axesm_context(ax); %#ok<NASGU>
delete(findobj(ax,'Tag','THREDDSVectors'));
if spacing==0, spacing=max(1,ceil(max(size(result.Values))/40)); end
rows=1:spacing:size(result.Values,1); cols=1:spacing:size(result.Values,2);
indices=reshape(1:numel(result.Values),size(result.Values));
indices=indices(rows,cols);
indices=indices(isfinite(result.Eastward(indices)) & isfinite(result.Northward(indices)));
lat=double(result.Latitude(indices)); lon=double(result.Longitude(indices));
east=double(result.Eastward(indices)); north=double(result.Northward(indices));
% Convert physical east/north velocities to geographic displacements.
% The cosine correction is essential for eastward arrows at high latitudes.
dlat=rad2deg(north/6371008.8);
dlon=rad2deg(east/6371008.8)./cosd(lat);
speedMax=max(hypot(east,north),[],'omitnan');
scaleSeconds=1;
if ~isempty(speedMax) && speedMax>0
    span=min(diff(result.LatitudeLimits),diff(result.LongitudeLimits)*cosd(mean(lat)));
    scaleSeconds=0.7*deg2rad(span)*6371008.8/max(2,sqrt(numel(indices)))/speedMax;
end
arrows=quiverm(lat,lon,dlat*scaleSeconds,dlon*scaleSeconds,'k',0);
set(arrows,'Tag','THREDDSVectors','LineWidth',0.75);
display=struct('Spacing',spacing,'Indices',indices,'ScaleSeconds',scaleSeconds, ...
    'XData',{get(arrows,{'XData'})},'YData',{get(arrows,{'YData'})});
end
