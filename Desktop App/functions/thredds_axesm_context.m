function cleanup = thredds_axesm_context(ax)
%THREDDS_AXESM_CONTEXT Temporarily expose/select app axes for axesm functions.
% Keep the returned onCleanup alive until all current-axes mapping calls end.
fig = ancestor(ax,'figure');
previousFigure = get(groot,'CurrentFigure');
previousAxes = fig.CurrentAxes;
figureVisibility = fig.HandleVisibility;
axesVisibility = ax.HandleVisibility;
cleanup = onCleanup(@() restoreContext(ax,fig,previousFigure,previousAxes, ...
    figureVisibility,axesVisibility));
fig.HandleVisibility = 'on';
ax.HandleVisibility = 'on';
set(groot,'CurrentFigure',fig);
fig.CurrentAxes = ax;
end

function restoreContext(ax,fig,previousFigure,previousAxes,figureVisibility,axesVisibility)
if isgraphics(ax)
    ax.HandleVisibility = axesVisibility;
end
if isgraphics(fig)
    if isempty(previousAxes) || isgraphics(previousAxes)
        fig.CurrentAxes = previousAxes;
    end
    fig.HandleVisibility = figureVisibility;
end
if isempty(previousFigure) || isgraphics(previousFigure)
    set(groot,'CurrentFigure',previousFigure);
end
end
