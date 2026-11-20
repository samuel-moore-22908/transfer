# Lower-tail Pareto coefficients of consumption: HFCS and LCF

Two R scripts that estimate lower-tail Pareto coefficients by consumption category, using the same estimator (Alexandre G's functions from the Tail of Tales paper, adapted to the lower tail).

| Script | Data | Waves | Output |
|---|---|---|---|
| `scripts/pareto_HFCS_waves.R` | HFCS (`HFCS_final.RData`), Germany | 2014, 2017, 2021, 2023 | `output/wave_<year>/` |
| `scripts/pareto_LCF.R` | UK LCF, England, dvhh files read from the UKDS Stata zips | interview years 2011–2024 | `output/wave_<year>/` plus tables across years |

Paths are set at the top of each script (HFCS: section 2; LCF: section 0) and need changing for another machine.

## Method (both scripts)

For each consumption variable, normalised by its weighted mean, with zero and negative values dropped:

1. Candidate cut-offs x_max = weighted quantiles 0.03, 0.04, …, 0.30.
2. For each cut-off, keep x ≤ x_max and model the tail CDF as F(x) = (x / x_max)^ζ. The empirical CDF is weighted and recomputed within the tail.
3. Estimate ζ by weighted MLE, ζ = Σw / Σw·ln(x_max / x). An OLS of ln F on ln(x_max / x) through the origin (unweighted) is also computed but not used.
4. Keep the cut-off that minimises the max Kolmogorov–Smirnov distance between the fitted and empirical CDF.

Each script also produces eyeball-test plots (whole distribution and bottom 10%), a LaTeX summary table, and weighted Spearman rank correlations across goods with a heatmap.

## Script-specific details

**HFCS.** Runs each wave separately. The ζ estimates are averaged over the 5 implicates. Three adjustment cases are run: raw, reporting-adjusted, and reporting + representation with WID weights. Sample: reference person aged 19–80, zero food-at-home spending dropped.

**LCF.** The data build mirrors `create_LCF_consumption.do`:
- includes the Jan–Mar 2015 file, England only, 2025 interviews dropped;
- total consumption = (`p600t` + housing benefit `b230`) × 52;
- the 12 COICOP divisions are `p601t`–`p612t` × 52, with `b230` added to housing.

Sample: reference person aged 19–79 (`p396p` is top-coded at 80), zero food spending dropped. There are no implicates and only one weight (`weighta`). Section 8 stacks the years and takes the median ζ across years. See `../uk-lcf-consumption/` for the consumption measure.

## Checks against Stata (LCF, 2026-11-20)

- The R data build is identical to `create_LCF_consumption.do`: the same households, consumption values and weights.
- On the same sample and the same cut-offs, the R function's OLS, MLE and KS statistics match Stata computations of the same quantities to within 4e-14.
- `create_LCF_pareto.do` (weighted `reg ln F ln x` with a constant, bottom *i*%) differs from the R OLS almost entirely because of the constant. Dropping the weights and the constant from the Stata regression, with both sides scaled at the cut-off, reproduces the R OLS exactly. Dropping the weights alone changes almost nothing.
