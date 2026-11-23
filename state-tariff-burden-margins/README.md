# Tariff burden vs counterfactual margins

`create_burden_margins_figure.do` draws a three-panel figure of the change in each state's tariff burden (pp of GDP), Jan to Oct 2025, against the change in:

1. the actual effective rate, τ
2. the partner-margin rate, τ_PM: state partner shares, national sector mix within each partner (PM = B diag(c^s))
3. the sector-margin rate, τ_SM: state sector shares, national partner mix within each sector (SM = diag(h^s) A)

Output: `$FIG\scatter_burden_margins.pdf`, plus `$RAW\cf_tariffs.dta` (all months, with the gap/partner/sector/interaction split).

## How it combines the two scripts

| Step | Method from |
|---|---|
| Counterfactual rates from the H × C matrices (`loadmat`, `align`, PM and SM) | `create_matrix_CF.do` |
| State GDP parsing (BEA `state_GDP.csv`) | `create_tariff_maps.do` (see `../state-tariff-maps-v4/`) |
| Implied burden: imports × actual rate, relative to Jan 2025, over monthly GDP | `create_tariff_maps.do` |
| Three-panel figure, same style as the dominance figures | `../state-tariff-maps-v4/` |

The script also prints the largest gap between the matrix τ and the effective rate in `weighted_by_state.dta`, and the correlation of their Jan to Oct changes. The two should agree, so this is a check that the inputs match.

## Inputs

- `$MAT` = `c(pwd)/matrix`: `N_`, `CgH_`, `HgC_`, `T_` and `S_<state>_` matrices by month (.dta, `hs6` plus country columns). Run the script from the folder that contains `matrix`.
- `$RAW\weighted_by_state.dta`, written by `create_tariff_maps.do`.
- `$SHP\state_GDP.csv`, the BEA file in the layout `create_tariff_maps.do` expects (4 rows before a "United States" row, Q4 GDP in column 6).

Switches at the top: `rebuild_cf` (0 = reuse `$RAW\cf_tariffs.dta`), `base_month` (780 = Jan 2025), `comp_month` (789 = Oct 2025).

## Checks (2026-11-23)

Run in Stata 18 on synthetic matrices built to the method's definitions. The tariff file had shuffled rows, an extra product and a missing partner column, to exercise `align()`. τ, τ_PM and τ_SM matched an independent Python calculation to within 3e-14 pp for 52 states × 2 months. All 51 states merged with the burden data, and the matrix τ equalled the weighted effective rate.
