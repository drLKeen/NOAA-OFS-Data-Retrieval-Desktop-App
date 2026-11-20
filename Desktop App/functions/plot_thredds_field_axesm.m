function result = plot_thredds_field_axesm(url,time,ax,callback,dataType,spacing)
% Load and draw a scalar or vector OFS field on native axesm coordinates.
if nargin<3, ax=[]; end
if nargin<4, callback=[]; end
if nargin<5, dataType="Temperature"; end
if nargin<6, spacing=0; end
timer=tic;
result=read_thredds_field(url,time,dataType,callback);
thredds_request_checkpoint(callback,'rendering');
graphicsTimer=tic;
if isempty(ax), fig=figure('Name','THREDDS field'); ax=axes(fig);
else, fig=ancestor(ax,'figure'); end
context=thredds_axesm_context(ax); %#ok<NASGU>
cla(ax,'reset');
axesm('mercator','MapLatLimit',result.LatitudeLimits, ...
    'MapLonLimit',result.LongitudeLimits,'Frame','on','Grid','on', ...
    'MeridianLabel','on','ParallelLabel','on');
axis(ax,'off');
result.Surface=gobjects(0); result.Arrows=gobjects(0); result.VectorDisplay=struct;
if result.Spec.IsVector
    [result.Arrows,result.VectorDisplay]=thredds_draw_vectors(ax,result,spacing);
    colorbar(ax,'off');
else
    result.Surface=pcolorm(result.Latitude,result.Longitude,result.Values, ...
        'FaceColor','interp','EdgeColor','none');
    clim(ax,result.DisplayLimits); colormap(ax,turbo(256));
    cb=colorbar(ax); cb.FontSize=14;
    ylabel(cb,result.Spec.Units,'FontSize',14);
end
result.LandPatch=thredds_axesm_background(ax,result.LatitudeLimits,result.LongitudeLimits);
tightmap;
title(ax,{char(result.DataType),char(string(result.SelectedTime)+' UTC')});
subtitle(ax,result.Spec.Description);
drawnow;
result.Figure=fig; result.Axes=ax;
result.Timings=struct('Interpolation',0,'Graphics',toc(graphicsTimer),'Total',toc(timer));
end
