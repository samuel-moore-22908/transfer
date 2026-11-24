# State tariff event study

`exploratory_event_study.do` runs weighted two-way fixed effects event studies of state outcomes on state tariff exposure.

- **Outcomes (LHS):** `state_month_wide.csv` from the `tariff_states` pipeline (`pull_data.py`): unemployment rate; total nonfarm, mining/logging/construction, manufacturing, wholesale, retail and transportation/warehousing/utilities employment; business applications; housing permits; imports from China, Canada and Mexico. All in logs.
- **Exposure (RHS):** `RHS_variables_raw.dta` from `create_tariff_maps.do` (see `../state-tariff-maps-v4/`): log effective tariff rate and log implied duties as % of GDP.
- **Specification:** exposure x event-time dummies, event month April 2025, window June 2024 to the last month with state GDP, reference period March 2025. State and month fixed effects, weighted by pre-period mean state GDP, standard errors clustered by state (`reghdfe`).

## Exposure window

Exposure is each state's mean of the RHS variable over **April-June 2025** (`EXP_FROM = 0`, `EXP_TO = 2`), standardized across states. Later tariff changes don't enter the exposure measure, so coefficients that keep rising after June 2025 read as a delayed response to early exposure. The earlier version averaged over the whole post period.

Outputs carry the suffix in `SUFFIX` (`_aprjun`): `es_<y>_<x>_aprjun.png` in `$FIG` and `es_<x>_aprjun.csv` in `$TAB`, so they don't overwrite the full-post-period results.

Paths are set in the globals at the top (`ROOT`, `RAW`, `FIG`, `TAB`). Needs `reghdfe`, `parmest` and `estout` (`ssc install`).
