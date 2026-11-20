# Bundled continuous IPCC colormaps

These are the 16 continuous palettes selected by the [Standard Climate
Colormaps for MATLAB File Exchange example](https://www.mathworks.com/matlabcentral/fileexchange/180750-standard-climate-colormaps-for-matlab).
Categorical and discrete variants are excluded.

The `.txt` files are unmodified RGB tables downloaded on 2026-10-20 from
[IPCC-WG1/colormaps](https://github.com/IPCC-WG1/colormaps/tree/b7d3849d4fa521d2583b91360e875e38f191d209/continuous_colormaps_rgb_0-255),
revision `b7d3849d4fa521d2583b91360e875e38f191d209`.
The MathWorks example was inspected at revision
`9c812f76a9f57f91d37ac1609e43522a50a99b05`.

`continuous.mat` contains the `ipccPalettes` struct, with one field per
palette. Each field is the original 256-by-3 integer RGB table divided by
255, stored as double precision. No resampling, reversal, or reduction is
applied. This matches the example's `colormap(uint8(A))` colors.

`thredds_ipcc_colormap` loads this local MAT-file once, then retains the
collection in memory (98,304 bytes of RGB data). There are no runtime
downloads, update checks, or network fallbacks. Include this folder when
sharing the app. The text files preserve the upstream source for auditing;
only `continuous.mat` is needed at runtime.

Palettes: `chem_div`, `chem_seq`, `cryo_div`, `cryo_seq`, `misc_div`,
`misc_seq_1`, `misc_seq_2`, `misc_seq_3`, `prec_div`, `prec_seq`,
`slev_div`, `slev_seq`, `temp_div`, `temp_seq`, `wind_div`, `wind_seq`.

Credit: IPCC Working Group I colormap repository. The MathWorks example
is by Kostas Leptokaropoulos and acknowledges Crameri, F. (2018),
*Scientific colour maps*, Zenodo, https://doi.org/10.5281/zenodo.1243862.
