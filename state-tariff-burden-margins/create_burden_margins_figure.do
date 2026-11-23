//------------------------------------------------------------------------------
* AUTHOR:  SAM MOORE
* PURPOSE: Three-panel figure: change in tariff burden (pp of GDP), Jan -> Oct
*          2025, against the change in (A) the actual state effective rate,
*          (B) the partner-margin rate and (C) the sector-margin rate.
*
*          Combines two methods:
*            - create_matrix_CF.do: counterfactual rates from the H x C matrices
*                PM^s = B diag(c^s)    state partner margin (national sector mix within partner)
*                SM^s = diag(h^s) A    state sector margin  (national partner mix within sector)
*                tau = 100 sum(S^s .* T), tau_PM = 100 sum(PM^s .* T), tau_SM = 100 sum(SM^s .* T)
*            - create_tariff_maps_updated.do: implied tariff burden as a share of
*              state GDP (imports x actual effective rate, relative to Jan 2025)
*
*          Inputs:  $MAT  N_, CgH_, HgC_, T_, S_<state>_ matrices by month (.dta)
*                   $RAW\weighted_by_state.dta   (from create_tariff_maps_updated.do)
*                   $SHP\state_GDP.csv           (BEA, as in create_tariff_maps_updated.do)
*          Outputs: $RAW\cf_tariffs.dta, $FIG\scatter_burden_margins.pdf
//------------------------------------------------------------------------------

clear all
set more off

global ROOT = "C:\Users\G1SAM03\FRBC Dropbox\Sam Moore\tariff_states"
global SHP  = "$ROOT\data"
global RAW  = "$ROOT\out"
global FIG  = "$ROOT\figures"
global MAT  "`c(pwd)'/matrix"

cap mkdir "$FIG"

* 1 = recompute the counterfactual rates from the matrices; 0 = reuse $RAW\cf_tariffs.dta
local rebuild_cf = 1

* base and comparison months
local base_month = 780     // Jan 2025
local comp_month = 789     // Oct 2025

//------------------------------------------------------------------------------
* 1. Counterfactual rates (method of create_matrix_CF.do)
//------------------------------------------------------------------------------

* Mata helpers (defined outside the if block: Stata does not allow mata ... end inside braces)
mata:
mata clear

// load a matrix dta (hs6 + c#### columns). Fills rl (rows) and cl (cols).
real matrix loadmat(string scalar fn, transmorphic rl, transmorphic cl)
{
    stata(`"use ""' + fn + `"", clear"')
    rl = st_sdata(., "hs6")
    cl = st_varname(2..st_nvar())
    return(st_data(., cl))
}

// place T (labels Trl, Tcl) onto the grid (rl, cl). Unmatched cells = 0.
real matrix align(real matrix T, string colvector Trl, string rowvector Tcl,
                  string colvector rl,  string rowvector cl)
{
    transmorphic A
    real colvector ri, keepr
    real rowvector ci, keepc
    real scalar i
    real matrix out

    A = asarray_create()
    asarray_notfound(A, 0)
    for (i=1; i<=rows(rl); i++) asarray(A, rl[i], i)
    ri = J(rows(Trl), 1, 0)
    for (i=1; i<=rows(Trl); i++) ri[i] = asarray(A, Trl[i])

    A = asarray_create()
    asarray_notfound(A, 0)
    for (i=1; i<=cols(cl); i++) asarray(A, cl[i], i)
    ci = J(1, cols(Tcl), 0)
    for (i=1; i<=cols(Tcl); i++) ci[i] = asarray(A, Tcl[i])

    keepr = selectindex(ri)
    keepc = selectindex(ci)
    out = J(rows(rl), cols(cl), 0)
    out[ri[keepr], ci[keepc]] = T[keepr, keepc]
    return(out)
}
end

if `rebuild_cf' {


    * months available (filenames are lowercased by : dir on Windows)
    local nfiles : dir "$MAT" files "N_*.dta"
    local months
    foreach f of local nfiles {
        local f = lower("`f'")
        local m = substr("`f'", 3, strlen("`f'") - 6)      // drop "n_" and ".dta"
        local months `months' `m'
    }
    local months : list sort months

    tempname res
    postfile `res' str40 state double(date tau tauN tau_PM tau_SM) ///
        using "$RAW/cf_tariffs_long", replace

    foreach m of local months {

        * ---- national objects for month m (all H x C) ----
        mata: N  = loadmat("$MAT/N_`m'.dta",   Nrl=., Ncl=.)   // national import shares
        mata: A  = loadmat("$MAT/CgH_`m'.dta", Arl=., Acl=.)   // P(partner | sector), rows sum to 1
        mata: B  = loadmat("$MAT/HgC_`m'.dta", Brl=., Bcl=.)   // P(sector | partner), cols sum to 1
        mata: T0 = loadmat("$MAT/T_`m'.dta",   Trl=., Tcl=.)   // tariff schedule (rates)
        mata: T  = align(T0, Trl, Tcl, Nrl, Ncl)               // on the same H x C grid as N

        mata: H = rows(N)
        mata: C = cols(N)
        mata: tauN = 100 * sum(N :* T)                          // national effective rate, pp

        * ---- states ----
        local sfiles : dir "$MAT" files "S_*_`m'.dta"
        foreach f of local sfiles {

            local f = lower("`f'")
            local s = substr("`f'", 3, strlen("`f'") - 2 - strlen("_`m'.dta"))

            mata: S  = loadmat("$MAT/`f'", Srl=., Scl=.)       // state import shares, H x C
            mata: hs = S  * J(C, 1, 1)                          // h^s: sector shares (H x 1)
            mata: cs = S' * J(H, 1, 1)                          // c^s: partner shares (C x 1)
            mata: PM = B * diag(cs)                             // PM^s = B diag(c^s)
            mata: SM = hs :* A                                  // SM^s = diag(h^s) A

            mata: st_numscalar("r_tau",    100 * sum(S  :* T))
            mata: st_numscalar("r_tau_PM", 100 * sum(PM :* T))
            mata: st_numscalar("r_tau_SM", 100 * sum(SM :* T))
            mata: st_numscalar("r_tauN",   tauN)

            post `res' ("`s'") (`m') (r_tau) (r_tauN) (r_tau_PM) (r_tau_SM)
        }
    }
    postclose `res'

    use "$RAW/cf_tariffs_long", clear
    format date %tm
    gen double gap      = tau    - tauN
    gen double partner  = tau_PM - tauN
    gen double sector   = tau_SM - tauN
    gen double interact = gap - partner - sector
    label var tau    "actual state effective rate (pp)"
    label var tauN   "national effective rate (pp)"
    label var tau_PM "PM^s: state partner margin, national sector mix within partner (pp)"
    label var tau_SM "SM^s: state sector margin, national partner mix within sector (pp)"
    compress
    save "$RAW/cf_tariffs", replace
}

* ---- changes in the three rates, base -> comparison month ----
tempfile cf
use "$RAW/cf_tariffs", clear
drop if inlist(state, "pr", "xx", "vi")
replace state = upper(state)
foreach v of varlist tau tau_PM tau_SM {
    gen temp = `v' if date == `base_month'
    bys state: egen baseline = min(temp)
    gen delta_`v' = `v' - baseline
    drop temp baseline
}
keep if date == `comp_month'
keep state tau delta_tau delta_tau_PM delta_tau_SM
save "`cf'", replace

//------------------------------------------------------------------------------
* 2. State GDP (as in create_tariff_maps_updated.do)
//------------------------------------------------------------------------------

tempfile state_GDP

import delimited "$SHP/state_GDP.csv", clear
drop if _n <= 4
keep v2 v6
ren (v2 v6) (state Q4_GDP)
destring Q4_GDP, replace

drop if _n == 1 | _n > 52

gen state_abbrev = ""
replace state_abbrev = "AL" if state == "Alabama"
replace state_abbrev = "AK" if state == "Alaska"
replace state_abbrev = "AZ" if state == "Arizona"
replace state_abbrev = "AR" if state == "Arkansas"
replace state_abbrev = "CA" if state == "California"
replace state_abbrev = "CO" if state == "Colorado"
replace state_abbrev = "CT" if state == "Connecticut"
replace state_abbrev = "DE" if state == "Delaware"
replace state_abbrev = "DC" if state == "District of Columbia"
replace state_abbrev = "FL" if state == "Florida"
replace state_abbrev = "GA" if state == "Georgia"
replace state_abbrev = "HI" if state == "Hawaii"
replace state_abbrev = "ID" if state == "Idaho"
replace state_abbrev = "IL" if state == "Illinois"
replace state_abbrev = "IN" if state == "Indiana"
replace state_abbrev = "IA" if state == "Iowa"
replace state_abbrev = "KS" if state == "Kansas"
replace state_abbrev = "KY" if state == "Kentucky"
replace state_abbrev = "LA" if state == "Louisiana"
replace state_abbrev = "ME" if state == "Maine"
replace state_abbrev = "MD" if state == "Maryland"
replace state_abbrev = "MA" if state == "Massachusetts"
replace state_abbrev = "MI" if state == "Michigan"
replace state_abbrev = "MN" if state == "Minnesota"
replace state_abbrev = "MS" if state == "Mississippi"
replace state_abbrev = "MO" if state == "Missouri"
replace state_abbrev = "MT" if state == "Montana"
replace state_abbrev = "NE" if state == "Nebraska"
replace state_abbrev = "NV" if state == "Nevada"
replace state_abbrev = "NH" if state == "New Hampshire"
replace state_abbrev = "NJ" if state == "New Jersey"
replace state_abbrev = "NM" if state == "New Mexico"
replace state_abbrev = "NY" if state == "New York"
replace state_abbrev = "NC" if state == "North Carolina"
replace state_abbrev = "ND" if state == "North Dakota"
replace state_abbrev = "OH" if state == "Ohio"
replace state_abbrev = "OK" if state == "Oklahoma"
replace state_abbrev = "OR" if state == "Oregon"
replace state_abbrev = "PA" if state == "Pennsylvania"
replace state_abbrev = "RI" if state == "Rhode Island"
replace state_abbrev = "SC" if state == "South Carolina"
replace state_abbrev = "SD" if state == "South Dakota"
replace state_abbrev = "TN" if state == "Tennessee"
replace state_abbrev = "TX" if state == "Texas"
replace state_abbrev = "UT" if state == "Utah"
replace state_abbrev = "VT" if state == "Vermont"
replace state_abbrev = "VA" if state == "Virginia"
replace state_abbrev = "WA" if state == "Washington"
replace state_abbrev = "WV" if state == "West Virginia"
replace state_abbrev = "WI" if state == "Wisconsin"
replace state_abbrev = "WY" if state == "Wyoming"

drop state
ren state_abbrev state
save "`state_GDP'", replace

//------------------------------------------------------------------------------
* 3. Implied tariff burden (as in create_tariff_maps_updated.do)
//------------------------------------------------------------------------------

tempfile burden
use "$RAW\weighted_by_state.dta", clear
drop if inlist(state, "XX", "PR", "VI")

replace effective_rate = effective_rate*100

gen temp = effective_rate if date == `base_month'
bys state: egen baseline = min(temp)
drop temp
gen delta_rate = effective_rate - baseline

merge m:1 state using "`state_GDP'"
drop if _merge == 2
drop _merge

gen temp = (effective_rate*(con_val_usd/1e6))/100 if date == `base_month'
bys state: egen baseline_burden = min(temp)
drop temp

gen implied_burden    = ((con_val_usd/1e6)*effective_rate)/100
gen delta_burden      = implied_burden - baseline_burden
gen delta_burden_pGDP = ((delta_burden)/(Q4_GDP/12))*100   // annualized to monthly

keep if date == `comp_month'
keep state effective_rate delta_rate delta_burden_pGDP
save "`burden'", replace

//------------------------------------------------------------------------------
* 4. Combine
//------------------------------------------------------------------------------

use "`burden'", clear
merge 1:1 state using "`cf'"
tab _merge
keep if _merge == 3
drop _merge
keep if !mi(delta_burden_pGDP, delta_tau, delta_tau_PM, delta_tau_SM)

* the two methods measure the same actual rate: report how close they are
gen double rate_gap = abs(tau - effective_rate)
qui sum rate_gap
display as text "Max |matrix tau - weighted effective rate| in " %tm `comp_month' ///
    ": " as result %6.4f r(max) " pp"
qui corr delta_tau delta_rate
display as text "Correlation of the two Jan->Oct rate changes: " as result %6.4f r(rho)

//------------------------------------------------------------------------------
* 5. Figure
//------------------------------------------------------------------------------

* ---- common axes for all three panels: start at 0, round tops --------------
local xmax = 0
foreach v in delta_tau delta_tau_PM delta_tau_SM {
    qui sum `v'
    local xmax = max(`xmax', r(max))
}
local xtop = ceil(`xmax'/5)*5

qui sum delta_burden_pGDP
local ymax = r(max)
foreach v in delta_tau delta_tau_PM delta_tau_SM {
    qui regress delta_burden_pGDP `v'
    qui sum `v'
    local ymax = max(`ymax', _b[_cons] + _b[`v']*r(max))   // fit line end (data range)
}
local ystep = cond(`ymax' <= 1, 0.2, cond(`ymax' <= 3, 0.5, 1))
local ytop  = ceil(`ymax'/`ystep')*`ystep'

* ---- one panel (same style as the dominance figures) ------------------------
cap program drop burden_panel
program define burden_panel
    syntax varname, xtitle(string) name(string) xtop(real) ytop(real) ystep(real)
    twoway                                                                  ///
        (lfit delta_burden_pGDP `varlist',                                  ///
            lcolor(gs8) lpattern(dash) lwidth(medthin))                     ///
        (scatter delta_burden_pGDP `varlist',                               ///
            mcolor(blue) msymbol(O) msize(medium)                           ///
            mlabel(state) mlabposition(3) mlabcolor(blue)                   ///
            mlabsize(small) mlabgap(*0.6)),                                 ///
        ytitle("Change in tariff burden (pp of GDP)", size(medlarge))       ///
        xtitle("`xtitle'", size(medlarge))                                  ///
        xscale(range(0 `xtop')) yscale(range(0 `ytop'))                     ///
        xlabel(0(5)`xtop', labsize(medlarge) nogrid noticks)                ///
        ylabel(0(`ystep')`ytop', format(%3.1f) labsize(medlarge) angle(90)  ///
               nogrid noticks)                                              ///
        plotregion(style(none) margin(small)) graphregion(color(white))     ///
        aspectratio(1) legend(off) title("") name(`name', replace) nodraw
end

burden_panel delta_tau,    xtitle("Change in actual effective rate (pp)") ///
    name(p_rate)    xtop(`xtop') ytop(`ytop') ystep(`ystep')
burden_panel delta_tau_PM, xtitle("Change in partner margin rate (pp)")   ///
    name(p_partner) xtop(`xtop') ytop(`ytop') ystep(`ystep')
burden_panel delta_tau_SM, xtitle("Change in sector margin rate (pp)")    ///
    name(p_sector)  xtop(`xtop') ytop(`ytop') ystep(`ystep')

graph combine p_rate p_partner p_sector, rows(1) iscale(1) imargin(small)   ///
    xsize(16.5) ysize(5.5) graphregion(color(white))

graph export "$FIG\scatter_burden_margins.pdf", replace
