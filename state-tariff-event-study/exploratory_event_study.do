//------------------------------------------------------------------------------
* AUTHOR: SAM MOORE 
* DATE: 11/18/2026
* PURPOSE: Exploratory event study
//------------------------------------------------------------------------------

clear all
set more off

global ROOT = "C:\Users\G1SAM03\FRBC Dropbox\Sam Moore\tariff_states"
global SHP  = "$ROOT\data"
global RAW  = "$ROOT\out"
global FIG  = "$ROOT\figures"
global TAB  = "$ROOT\tables"

cap mkdir "$FIG"
cap mkdir "$TAB"

//------------------------------------------------------------------------------
* Import LHS (created using pull_LHS.py)
//------------------------------------------------------------------------------

import delimited "$RAW/state_month_wide.csv", clear 

gen mdate = mofd(date(date, "YMD"))
format mdate %tm
drop date 
ren (mdate state_abbr) (date state)

//------------------------------------------------------------------------------
* Add RHS (created using create_tariff_maps.do)
//------------------------------------------------------------------------------

merge 1:1 state date using "$RAW/RHS_variables_raw.dta"
drop if _merge ~= 3 //drops 2026 Q3 (we do not know state GDP over this interval)
drop _merge 

//------------------------------------------------------------------------------
* transform 
//------------------------------------------------------------------------------

* declutter 

keep state date unemp_rate_sa emp_total_nonfarm_sa emp_mlc_sa /// 
 emp_mfg_sa emp_wholesale_sa emp_retail_sa emp_twu_sa  ///
 bfs_ba_sa permits_units_total imports_china_con imports_canada_con imports_mexico_con /// 
 effective_rate implied_burden_p_GDP GDP
 
* interpolate unemployment rate during the govt. shutdown
 
sort state date
by state: replace unemp_rate_sa = (unemp_rate_sa[_n-1] + unemp_rate_sa[_n+1]) / 2 ///
	if missing(unemp_rate_sa) & !missing(unemp_rate_sa[_n-1]) & !missing(unemp_rate_sa[_n+1])
 
* log transform all of this crap 

ds state date, not 
foreach var in `r(varlist)' { 
	gen ln_`var' = ln(`var')
}

* no missing values ever 

//------------------------------------------------------------------------------
* set up the event study 
//------------------------------------------------------------------------------

* event window: 10 leads (Jun 2024 - Mar 2025), 15 lags (Apr 2025 - Jul 2026)
* event month Apr 2025 = L0; Mar 2025 = F1 is the omitted reference period

local EVENT = tm(2025m4)
local NLEAD = 10
local NLAG  = 15

gen rel = date - `EVENT'
keep if inrange(rel, -`NLEAD', `NLAG')

* time-invariant weight: pre-period mean GDP by state

bys state: egen gdp_w = mean(cond(rel < 0, GDP, .))

* exposure in SD units: state-level mean of each RHS over the exposure window,
* standardized across states (so coefficients = effect of a 1 SD increase in exposure)
* exposure window: Apr 2025 - Jun 2025 (rel 0-2), so later tariff changes don't
* enter z_s and rising lags can be read as a delayed response to early exposure

local EXP_FROM = 0
local EXP_TO   = 2
local EXP_LAB  "Apr-Jun 2025"
local SUFFIX   "_aprjun"   // appended to figure/table names; keeps the old outputs

local XVARS ln_effective_rate ln_implied_burden_p_GDP

foreach x of local XVARS {
	bys state: egen `x'_post = mean(cond(inrange(rel, `EXP_FROM', `EXP_TO'), `x', .))
	bys state: gen tag = _n == 1
	qui sum `x'_post if tag
	gen sd_`x' = (`x'_post - r(mean)) / r(sd)
	drop `x'_post tag
}

* outcomes 

local YVARS ln_unemp_rate_sa ln_emp_total_nonfarm_sa ln_emp_mlc_sa ///
	ln_emp_mfg_sa ln_emp_wholesale_sa ln_emp_retail_sa ln_emp_twu_sa ///
	ln_bfs_ba_sa ln_permits_units_total ln_imports_china_con ///
	ln_imports_canada_con ln_imports_mexico_con
	
//------------------------------------------------------------------------------
* run the event study 
//------------------------------------------------------------------------------

local i = 0
foreach x of local XVARS {
	local ++i
	
	* build F* (leads) and L* (lags) = exposure x event-time dummy
	* F1 (Mar 2025) is intentionally not created -> omitted category
	cap drop F* L*
	forvalues k = 2/`NLEAD' {
		gen F`k' = sd_`x' * (rel == -`k')
	}
	forvalues k = 0/`NLAG' {
		gen L`k' = sd_`x' * (rel == `k')
	}
	
	local j = 0
	foreach y of local YVARS {
		local ++j
		
		di as text _n "{hline 78}" _n "Y = `y'    X = `x'" _n "{hline 78}"
		
		reghdfe `y' F* L* [aw = gdp_w], absorb(state date) vce(cluster state)
		estimates store es_`i'_`j'   // short name: avoids 32-char limit
		
		* figure via parmest 
		preserve
			parmest, norestore
			
			gen rel = .
			replace rel = -real(substr(parm, 2, .)) if substr(parm, 1, 1) == "F"
			replace rel =  real(substr(parm, 2, .)) if substr(parm, 1, 1) == "L"
			drop if missing(rel)
			
			* add the omitted period (Mar 2025) as a zero
			set obs `=_N + 1'
			replace rel      = -1 if missing(rel)
			replace estimate = 0  if rel == -1
			replace min95    = 0  if rel == -1
			replace max95    = 0  if rel == -1
			
			sort rel
			
			twoway (rcap min95 max95 rel, lcolor(gs10)) ///
				   (connected estimate rel, mcolor(navy) lcolor(navy) msymbol(O)), ///
				   yline(0, lcolor(black) lpattern(dash)) ///
				   xline(-0.5, lcolor(red) lpattern(dash)) ///
				   xlabel(-`NLEAD'(2)`NLAG') ///
				   xtitle("Months relative to April 2025") ///
				   ytitle("Effect of 1 SD exposure on `y'") ///
				   title("`y'", size(medium)) ///
				   subtitle("Exposure: `x', `EXP_LAB' mean (SD units); weighted by pre-period GDP", size(small)) ///
				   legend(off) graphregion(color(white))

			graph export "$FIG/es_`y'_`x'`SUFFIX'.png", replace width(1600)
		restore
	}
}

//------------------------------------------------------------------------------
* tables 
//------------------------------------------------------------------------------

local Forder
forvalues k = `NLEAD'(-1)2 {
	local Forder `Forder' F`k'
}

local i = 0
foreach x of local XVARS {
	local ++i
	local models
	forvalues j = 1/`: word count `YVARS'' {
		local models `models' es_`i'_`j'
	}
	
	esttab `models' using "$TAB/es_`x'`SUFFIX'.csv", replace ///
		b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
		keep(F* L*) order(`Forder' L*) ///
		mtitles(`YVARS') ///
		title("Event study: exposure = `x', `EXP_LAB' mean (SD units); ref. period = Mar 2025") ///
		stats(N r2_within, labels("N" "Within R2") fmt(%9.0fc %9.3f))
}
