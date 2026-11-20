function landPatch = thredds_axesm_background(ax,latlim,lonlim)
%thredds_axesm_background Draw filled GSHHS land and a regional grid.
%   P = thredds_axesm_background(AX,LATLIM,LONLIM) draws high-resolution
%   land polygons and a regional graticule on an axesm-based map.
%   P is the editable land patch, rendered without border lines.
%   Land includes lake holes and uses the project's GMT GSHHG dataset.
%
%   See also gridm, patchm, thredds_gshhs_land

appRoot = fileparts(fileparts(mfilename('fullpath')));
filename = fullfile(appRoot,'gshhg-gmt-2.3.7','binned_GSHHS_h.nc');
land = thredds_gshhs_land(filename,latlim,lonlim);
context = thredds_axesm_context(ax); %#ok<NASGU>
delete(findobj(ax,'Tag','THREDDSCoastline'));
delete(findobj(ax,'Tag','THREDDSLand'));
landPatch = gobjects(0);
if land.NumRegions>0
    [landLon,landLat] = boundary(land);
    landPatch = patchm(landLat,landLon,0.5,[0.53125 0.53125 0.53125], ...
        'EdgeColor','none','Tag','THREDDSLand');
end
steps = [0.05 0.1 0.2 0.5 1 2 5 10 15 30 60];
[~,ilat] = min(abs(log(steps/(diff(latlim)/5))));
[~,ilon] = min(abs(log(steps/(diff(lonlim)/5))));
ax.FontSize = 14;
setm(ax,'FontSize',14,'MLineLocation',steps(ilon),'PLineLocation',steps(ilat), ...
    'MLabelLocation',steps(ilon),'PLabelLocation',steps(ilat), ...
    'MLabelParallel','south','MLabelRound',-2,'PLabelRound',-2, ...
    'GAltitude',2,'GColor',[0.45 0.45 0.45],'GLineStyle',':');
gridm('on');
mlabel('on');
plabel('on');
% uimaptbx skips its legacy tag/property popup when the figure has a
% button-down callback. Its unparented tag control otherwise opens a new
% figure for an app with hidden handles. Guard the figure so this also
% covers map objects recreated by Fit, while preserving custom callbacks.
fig = ancestor(ax,'figure');
if isempty(fig.WindowButtonDownFcn)
    fig.WindowButtonDownFcn = @(~,~) [];
end
end
