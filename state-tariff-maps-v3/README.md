# State tariff maps (v3)

`create_tariff_maps.do` builds state-level effective tariff rates from HS6 state imports and effective tariffs, then draws two US state maps and a scatter:

- `rate_heterogeneity.pdf`: increase in the effective tariff rate, Jan. 2025 to Oct. 2025 (pp)
- `share_heterogeneity.pdf`: increase in the implied tariff burden as a share of GDP
- `scatter_rate_burden.pdf`: burden change against rate change

Paths are set in the globals at the top (`ROOT`, `SHP`, `RAW`, `FIG`). The maps need `spmap` and `shp2dta` (`ssc install`), and the Census `cb_2018_us_state_20m` shapefile converted once with the commented `shp2dta` line.

This version supersedes `../state-tariff-maps/` and `../state-tariff-maps-v2/`. Only the map section (from "Make some Maps" onward) differs from the original do-file; the data build is unchanged.

## Map layout

- Larger text: state labels `medium`, legend keys `medium`, legend title and note `medlarge`.
- Light yellow-green-blue palette instead of `Blues`, so black labels stay readable on every class (contrast with black at least about 4.7:1). Maps with fewer than 9 classes take evenly spaced colours from the same ramp.
- In-state labels sit at each state's widest section. Among label-height (0.9 degree) horizontal bands, the code uses those within about 5% of the state's widest inside span, centres the label vertically in that run and horizontally in the span. MI uses its single widest band. The positions were computed from `cb_2018_us_state_20m` and are written as a commented block of `cx`/`cy` values.
- Leader lines for states whose labels do not fit their widest section (checked against measured label widths):
  - Atlantic column (text right of the line): ME, VT, NH, MA, RI, CT, NJ, DE, MD, DC, VA, WV, SC, GA, FL
  - Top row (text right of the line): IN, OH. IN's leader bends in Lake Michigan (`vx`/`vy`) so it passes west of the MI label.
  - Bottom row in the Gulf of Mexico (text below the line): MS, AL
- Leaders can take one optional bend point per state through `vx`/`vy` in the prep section; states without one get a straight line.

Placement was checked by running the map section in Stata 18 on synthetic data with the same label lengths as the October 2025 values. On the burden map, VA and OH labels would fit inside their states if the real values are short (for example "1.2"); they keep leaders here because both maps share one layout.
