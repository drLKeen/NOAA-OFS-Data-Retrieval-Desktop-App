# NOAA OFS native-grid field viewer

`THREDDSNativeApp.mlapp` displays NOAA Ocean Forecast System near-surface
temperature, salinity, wind, currents, and water level from THREDDS OPeNDAP.
Scalar maps draw the native ROMS grid with `pcolorm` on a Mercator `axesm`
map; wind and current maps use `quiverm`. `patchm` draws the filled land.

## Requirements and launch

MATLAB and Mapping Toolbox are required. The app is verified with MATLAB
R2026b. Internet access to NOAA is required for availability checks and data
retrieval. Coastline geometry and all colormaps are bundled locally.

Set MATLAB's current folder to this folder, then run:

```matlab
addpath(fullfile(pwd,'functions'));
app = THREDDSNativeApp;
```

To edit the app, open `THREDDSNativeApp.mlapp` in App Designer. Keep the
`functions` and `gshhg-gmt-2.3.7` folders beside the app when moving or
sharing it. The shoreline reader resolves its data relative to this folder;
the geography folder does not need to be added to the MATLAB path.

## Using the app

1. Select an OFS system, Forecast or Nowcast, and a data type, then choose a published
   UTC date and time. Availability is checked at startup and when needed;
   Refresh forces a new check. Listings are cached for five minutes.
2. Select **Load map** to retrieve one time slice. Temperature, salinity,
   and currents use the uppermost model layer; wind and water level are 2-D.
   Cancel is handled at checkpoints between network and processing calls;
   an active synchronous network request must finish first.
3. For scalar fields, choose a colormap, toggle Reverse colormap, or adjust
   automatic/manual color limits. For vectors, adjust **Arrow spacing**:
   `0` chooses readable spacing, `1` plots every point, and larger integers
   select every Nth grid row/column. Show land and Fit map apply to all types.
4. Use **Export** after loading data to save Map + data, Map only, or Data
   only. PNG captures the current map view; MAT preserves the full native
   arrays. JSON records source and display metadata. Each export uses a new
   output folder and avoids overwriting an existing package.

CBOFS, CIOFS, DBOFS, GOMOFS, and TBOFS support all five data choices.
NYOFS is listed but loading is disabled: its different model grid and
multi-time nowcast files require a separate adapter. The reader requires
the ROMS schema. Temperature is model potential temperature, not satellite
skin temperature. Water level is relative to the model datum, not an
assumed NOAA tidal datum. Color-limit controls are unit agnostic; scalar
colorbars show deg C (temperature), PSU (ROMS practical salinity), or meters
(water level). Explicit salinity units in the source take precedence over
the PSU convention. Wind and current map annotations show m/s.
Forecast uses NOAA's rolling best forecast
aggregation; Nowcast resolves published files and checks their timestamps.

Wind and current arrows point toward flow, with length proportional to speed
in m/s; lengths are scaled for visibility, not a forecast particle trajectory.
Grid-relative components are rotated using the model's `angle` field.
Staggered current components are averaged from neighboring faces to rho points;
outer edges use the nearest face and missing/dry faces are not bridged.
Arrow spacing affects display only. MAT exports retain full scalar fields,
east/north vectors, grid angle, source vector components, their native coordinates
and masks, and source variable attributes. JSON records the display spacing,
arrow scale, units, selection, and source. Temperature exports also retain the
legacy `TemperatureC` field.

## Repository contents

| Location | Purpose |
| --- | --- |
| `THREDDSNativeApp.mlapp` | App Designer interface, callbacks, and app state |
| `functions/read_thredds_field.m`, `plot_thredds_field_axesm.m` | Selected-field OPeNDAP retrieval and rendering |
| `functions/thredds_rotate_vectors.m`, `thredds_draw_vectors.m` | Vector alignment, rotation, and quiverm display |
| `functions/plot_thredds_sst_axesm.m` | Legacy temperature-only entry point |
| `functions/resolve_thredds_dataset.m` | Forecast/nowcast dataset selection |
| `functions/thredds_*availability*.m`, `thredds_nowcast_times.m` | Published-time discovery and date/time selection |
| `functions/thredds_request_checkpoint.m` | Cooperative cancellation |
| `functions/thredds_axesm_*.m`, `thredds_gshhs_*.m` | Map context, graticule, and filled land polygons |
| `functions/thredds_export_dialog.m`, `export_thredds_result.m` | Export UI and PNG/MAT/JSON output |
| `functions/OFScmap.mat`, `thredds_viridis.m` | Local OFS and viridis palettes |
| `functions/thredds_ipcc_colormap.m`, `colormaps/ipcc/` | Local continuous IPCC palettes and provenance |
| `gshhg-gmt-2.3.7/binned_GSHHS_h.nc` | Full high-resolution shoreline geometry used by the app |
| `gshhg-gmt-2.3.7/README.TXT` | Upstream geography documentation and license notice |
| `tests/` | Availability, cancellation, export, land geometry, and resolver checks |

The 20 colormaps are OFS, turbo, parula, viridis, and 16 continuous IPCC
palettes. Palette selection and preview generation never download data.
IPCC palettes are loaded once from a local MAT-file and cached in memory.
The original IPCC text tables are retained for provenance and verification;
see [palette documentation](functions/colormaps/ipcc/README.md). Viridis
attribution and its CC0 dedication are recorded in `thredds_viridis.m`.

## Validation

From this folder, run the local checks without NOAA integration tests:

```matlab
addpath(fullfile(pwd,'functions'));
suite = testsuite('tests');
suite = suite.selectIf(~matlab.unittest.selectors.HasTag('Integration'));
results = run(suite);
assertSuccess(results);
```

To include the four live NOAA integration checks, use
`results = runtests('tests'); assertSuccess(results);` instead. Their
results depend on NOAA availability and retention of the requested files.

The app's own startup checks availability over the network. Unit tests
create their synthetic inputs and export packages in temporary folders.
