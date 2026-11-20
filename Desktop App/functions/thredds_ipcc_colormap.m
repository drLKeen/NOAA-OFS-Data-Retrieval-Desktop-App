function map = thredds_ipcc_colormap(name)
%thredds_ipcc_colormap Return a bundled continuous IPCC palette.
%   MAP = thredds_ipcc_colormap(NAME) returns the original 256-by-3 RGB
%   table for NAME, such as "temp_seq" or "prec_div", normalized to [0,1].
%   The local palette collection is loaded once per MATLAB session.
%
%   See also COLORMAP, thredds_viridis

persistent palettes
if isempty(palettes)
    data = load(fullfile(fileparts(mfilename('fullpath')), ...
        'colormaps','ipcc','continuous.mat'),'ipccPalettes');
    palettes = data.ipccPalettes;
end
if ~isfield(palettes,name)
    error('THREDDS:UnknownIPCCColormap', ...
        'Unknown continuous IPCC colormap: %s.',name);
end
map = palettes.(name);
end
