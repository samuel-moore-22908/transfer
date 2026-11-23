# State tariff maps (v2)

`create_tariff_maps.do` builds state-level effective tariff rates from HS6 state imports and effective tariffs, then draws two US state maps and a scatter:

- `rate_heterogeneity.pdf`: increase in the effective tariff rate, Jan. 2025 to Oct. 2025 (pp)
- `share_heterogeneity.pdf`: increase in the implied tariff burden as a share of GDP
- `scatter_rate_burden.pdf`: burden change against rate change

Paths are set in the globals at the top (`ROOT`, `SHP`, `RAW`, `FIG`). The maps need `spmap` and `shp2dta` (`ssc install`), and the Census `cb_2018_us_state_20m` shapefile converted once with the commented `shp2dta` line.

This version supersedes the layout in `../state-tariff-maps/`. Only the map section (from "Make some Maps" onward) differs from the original do-file; the data build is unchanged.

## Map layout

- Larger text: state labels `medium`, legend keys `medium`, legend title and note `medlarge`.
- Light yellow-green-blue palette instead of `Blues`, so black labels stay readable on every class (contrast with black at least about 4.7:1). Maps with fewer than 9 classes take evenly spaced colours from the same ramp.
- Leader lines for states whose labels do not fit:
  - Atlantic column (text right of the line): VT, NH, MA, RI, CT, NJ, DE, MD, DC, VA, WV, SC, GA
  - Top row over Lake Superior and Ontario (text right of the line): MN, MI, IN
  - Bottom row across the Gulf of Mexico (text below the line): LA, MS, AL
- Label nudges so the remaining labels fit inside their states (FL, OH, KY, NC, TN, ME and others).

Placement was checked by running the map section in Stata 18 on synthetic data with the same label lengths as the October 2025 values. If values gain digits, the tightest spots (WV/VA, NC/TN, AL/FL) may need another nudge.
