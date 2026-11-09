/*==============================================================================
  build_lcf_consumption.do

  Builds a pooled year x household repeated cross-section of ANNUAL household
  consumption from the UK Living Costs and Food Survey (LCF), 2011 to 2024-25,
  England only.

  Input : the UKDS Stata zips (SN 7272 ... 9603), one per release
  Output: one row per household per survey year, saved as $LCF_OUT

  Every substantive choice is tagged in the code as  >>> ASSUMPTION [Ax]
  and printed to the Results window/log when the script runs.
  See ../README.md for how p600t is built from item codes in each release.

  Run:  do build_lcf_consumption.do
        (or set any of the globals below before calling it to override them)
==============================================================================*/

version 16
clear all
set more off

*------------------------------------------------------------------------------
* Paths (override by defining the globals before running this file)
*------------------------------------------------------------------------------
if `"$LCF_ZIPS"' == "" global LCF_ZIPS "C:/Users/smoor/Downloads/LCF"
if `"$LCF_WORK"' == "" global LCF_WORK "$LCF_ZIPS/extracted"
* >>> ASSUMPTION [A0]: output goes next to the raw data, not into the git repo,
*     because the UKDS End User Licence does not allow redistributing microdata.
if `"$LCF_OUT"'  == "" global LCF_OUT  "$LCF_ZIPS/lcf_consumption_england_2011_2024.dta"

*------------------------------------------------------------------------------
* Switches
*------------------------------------------------------------------------------
* >>> ASSUMPTION [A2]: annualise weekly amounts with 52 weeks (ONS convention for
*     annual figures from LCF). Set to 365.25/7 (=52.18) if you prefer.
local weeks_per_year = 52
* >>> ASSUMPTION [A3]: England only (gorx 1-9). Set to 0 to keep the whole UK.
local england_only = 1
* >>> ASSUMPTION [A5]: keep the Jan-Mar 2015 households (separate file in SN 8210)
*     so there is no gap in calendar time. Set to 0 to drop them.
local include_2015q1 = 1
**# FIX [A11]: housing benefit add-back - switch
* >>> ASSUMPTION [A11]: count rent paid by housing benefit as consumption, i.e.
*     add the rent rebate b230 back onto the net rent inside p604t/p600t.
*     Set to 0 to reproduce the published (net-of-benefit) ONS totals.
local add_back_hb = 1
**# END FIX [A11]

*------------------------------------------------------------------------------
* Print the assumptions to the shell
*------------------------------------------------------------------------------
di _n as text "{hline 78}"
di as result "LCF annual consumption panel of cross-sections: assumptions" _n
di as text "[A0] Output: $LCF_OUT" _n ///
   "     (kept out of git: UKDS licence forbids redistributing the microdata)"
di as text "[A1] Consumption = published p600t (household total incl. children's" _n ///
   "     own spending; = p601t+...+p612t). NOT rebuilt from item codes: a rebuild" _n ///
   "     matches p600t for 96-100% of England households, mean gap < 0.05%," _n ///
   "     and residual gaps come from ONS steps on unreleased data." _n ///
   "     Excludes non-consumption p620tp (mortgage interest, council tax," _n ///
   "     pensions, savings, life insurance...) and imputed rent (none in LCF)."
di as text "[A2] Annual = weekly x `weeks_per_year'. Nominal GBP, NOT deflated."
di as text "[A3] England only = gorx 1-9: " cond(`england_only', "ON", "OFF")
di as text "[A4] Year: survey_year = first calendar year of the release" _n ///
   "     (2011-2014 calendar years; 2015 = Apr 2015-Mar 2016, ..., 2024 =" _n ///
   "     Apr 2024-Mar 2025). Interview calendar year/month kept separately."
di as text "[A5] Jan-Mar 2015 file (SN 8210, 2015q1): " ///
   cond(`include_2015q1', "INCLUDED", "DROPPED") _n ///
   "     If included it is coded survey_year=2015 with q1_2015=1, so survey" _n ///
   "     year 2015 spans 15 months and its weights sum to ~1.25x households." _n ///
   "     Fine for means/regressions; drop q1_2015==1 for weighted totals."
di as text "[A6] Weights: weighta (annual grossing weight, thousands of hh);" _n ///
   "     2024-25 uses cal_weight_annual from the v3 file (only file with weights)."
di as text "[A7] Negative p600t (a handful of hh with big refunds/sales) kept," _n ///
   "     flagged neg_cons=1. No trimming or top-coding applied."
di as text "[A8] 2024-25 amounts are released rounded to GBP 0.10 per week."
di as text "[A9] Known breaks (NOT harmonised, see README section 8):" _n ///
   "     2013 energy/flights redefine housing & transport divisions;" _n ///
   "     2018-19 telecoms redesign moves TV/phone bundle into communication;" _n ///
   "     2020-21 COVID (phone interviews, thin Apr 2020)."
di as text "[A10] hhid = SN*100000 + case: unique across the pool. LCF is not a" _n ///
   "     panel; the same address is never linked across years."
**# FIX [A11]: housing benefit add-back - printed assumption
di as text "[A11] Housing benefit added back to rent: " ///
   cond(`add_back_hb', "ON", "OFF (published net totals)") _n ///
   "     ONS nets rent rebates/housing benefit (b230) out of rent (b010, b020)," _n ///
   "     so benefit-funded rent is not consumption in p600t, and net rent can" _n ///
   "     go below zero (benefit > rent): every negative p600t comes from this." _n ///
   "     With [A11] ON: cons = p600t + b230, c_housing = p604t + b230." _n ///
   "     Net rent + b230 equals gross rent p257 for 97-99% of renters." _n ///
   "     b230 is the only housing transfer netted out of p600t (council tax" _n ///
   "     rebates sit in non-consumption). Universal Credit's housing element is" _n ///
   "     paid to the tenant, so UC claimants should already report gross rent" _n ///
   "     (not checkable in public data): [A11] then also makes HB and UC" _n ///
   "     claimants comparable as UC replaces HB (2018+)." _n ///
   "     Published p600t is kept as cons_annual_pub."
**# END FIX [A11]
di as text "{hline 78}" _n

*------------------------------------------------------------------------------
* Release table: SN, survey_year, path of the dvhh file inside the zip
*------------------------------------------------------------------------------
local sns 7272 7472 7702 7992 8210 8351 8459 8686 8803 9022 9123 9335 9468 9603
local f7272 "UKDA-7272-stata/stata/stata9_se/2011_dvhh_ukanon.dta"
local f7472 "UKDA-7472-stata/stata/stata11_se/2012_dvhh_ukanon.dta"
local f7702 "UKDA-7702-stata/stata/stata11_se/2013_dvhh_ukanon.dta"
local f7992 "UKDA-7992-stata/stata/stata11_se/2014_dvhh_ukanon.dta"
local f8210 "UKDA-8210-stata/stata/stata11_se/2015-16_dvhh_ukanon.dta"
local f8351 "UKDA-8351-stata/stata/stata13_se/2016_17_dvhh_ukanon.dta"
local f8459 "UKDA-8459-stata/stata/stata11_se/dvhh_ukanon_2017-18.dta"
local f8686 "UKDA-8686-stata/stata/stata13/2018_dvhh_ukanon.dta"
local f8803 "UKDA-8803-stata/stata/stata13/lcfs_2019_dvhh_ukanon.dta"
local f9022 "UKDA-9022-stata/stata/stata13/lcfs_2020_dvhh_ukanon.dta"
local f9123 "UKDA-9123-stata/stata/stata13_se/lcfs_2021_dvhh_ukanon.dta"
local f9335 "UKDA-9335-stata/stata/stata13_se/dvhh_ukanon_2022.dta"
local f9468 "UKDA-9468-stata/stata/stata13_se/dvhh_ukanon_v2_2023.dta"
* >>> ASSUMPTION [A6]: 2024-25 must use the v3 file; v2 has no weights.
local f9603 "UKDA-9603-stata/stata/stata13_se/dvhh_uk_anon_v3_2024.dta"
local f8210q1 "UKDA-8210-stata/stata/stata11_se/2015q1_dvhh_ukanon.dta"

local y7272 2011
local y7472 2012
local y7702 2013
local y7992 2014
local y8210 2015
local y8351 2016
local y8459 2017
local y8686 2018
local y8803 2019
local y9022 2020
local y9123 2021
local y9335 2022
local y9468 2023
local y9603 2024

local divs 601 602 603 604 605 606 607 608 609 610 611 612
local names food alctob clothing housing furnish health transport comms ///
            recreation education resthotel misc

*------------------------------------------------------------------------------
* Unzip any release that is not yet extracted
*------------------------------------------------------------------------------
capture mkdir "$LCF_WORK"
foreach sn of local sns {
    capture confirm file "$LCF_WORK/`sn'/`f`sn''"
    if _rc {
        local z : dir "$LCF_ZIPS" files "`sn'stata_*.zip"
        if `"`z'"' == "" {
            di as error "No zip for SN `sn' in $LCF_ZIPS"
            exit 601
        }
        di as text "Unzipping SN `sn' ..."
        capture mkdir "$LCF_WORK/`sn'"
        local here = c(pwd)
        quietly cd "$LCF_WORK/`sn'"
        foreach zz of local z {
            unzipfile "$LCF_ZIPS/`zz'", replace
        }
        quietly cd "`here'"
        confirm file "$LCF_WORK/`sn'/`f`sn''"
    }
}

*------------------------------------------------------------------------------
* Read one dvhh file, harmonise names, keep what we need
*------------------------------------------------------------------------------
capture program drop _lcf_read
program define _lcf_read
    args file sn sy q1
    use "`file'", clear
    rename *, lower

    if "`q1'" == "1" rename case1 case
    if `sn' == 9603 {
        rename cal_weight_annual    weighta
        rename cal_weight_quarterly weightq
    }

    * list p601t..p612t explicitly: in 2018-19 they are not stored in order,
    * so a p601t-p612t range would pull in unrelated variables
    keep case weighta weightq gorx year a055 a099 a049 p600t ///
         p601t p602t p603t p604t p605t p606t p607t p608t p609t p610t ///
         p611t p612t p620tp p630tp ///
         b010 b020 b230 p257   // FIX [A11]: rent variables for the add-back
    * strip value labels so the 15 files append cleanly
    foreach v of varlist _all {
        label values `v'
    }

    gen int  sn          = `sn'
    gen int  survey_year = `sy'
    gen byte q1_2015     = `q1'
end

*------------------------------------------------------------------------------
* Loop over releases and append
*------------------------------------------------------------------------------
tempfile pool
local first = 1
foreach sn of local sns {
    _lcf_read "$LCF_WORK/`sn'/`f`sn''" `sn' `y`sn'' 0
    if !`first' append using `pool'
    save `pool', replace
    local first = 0

    * >>> ASSUMPTION [A5]: Jan-Mar 2015 households coded to survey_year 2015
    if `sn' == 8210 & `include_2015q1' {
        _lcf_read "$LCF_WORK/8210/`f8210q1'" 8210 2015 1
        append using `pool'
        save `pool', replace
    }
}
use `pool', clear
label drop _all

*------------------------------------------------------------------------------
* Sample
*------------------------------------------------------------------------------
* >>> ASSUMPTION [A3]: England = gorx 1-9 (gorx 10-12 are Wales, Scotland, NI)
if `england_only' keep if inrange(gorx, 1, 9)

*------------------------------------------------------------------------------
* Identifiers, timing, weights
*------------------------------------------------------------------------------
* >>> ASSUMPTION [A10]: case is unique within a file; the 2015q1 cases
*     (7002-13231) do not overlap the 2015-16 cases (1-6236), so SN*1e5+case works
gen double hhid = sn*100000 + case
isid hhid
isid survey_year hhid

* Interview timing. a055 codes 21-32 are reissued cases: month = code - 20.
gen byte reissue   = a055 > 20 if !missing(a055)
gen byte int_month = cond(a055 > 20, a055 - 20, a055)
rename year int_year
* int_year is the calendar year of interview (e.g. 2016 for Jan-Mar of 2015-16)
rename a099 int_quarter
assert inrange(int_month, 1, 12)

* >>> ASSUMPTION [A4]: survey_year is the release (first calendar year), and
*     financial-year releases put Jan-Mar in the next calendar year
assert int_year == survey_year     if survey_year <= 2014
assert int_year == survey_year     if survey_year >= 2015 & int_quarter >= 2 & !q1_2015
assert int_year == survey_year + 1 if survey_year >= 2015 & int_quarter == 1 & !q1_2015
assert int_year == 2015 & int_quarter == 1 if q1_2015

* >>> ASSUMPTION [A6]: annual grossing weight (thousands of households)
rename weighta wt_annual
rename weightq wt_quarter
assert wt_annual > 0 & !missing(wt_annual)

*------------------------------------------------------------------------------
* Consumption
*------------------------------------------------------------------------------
* Sanity check: p600t = sum of the 12 divisions (2024-25 rounded to 0.10)
egen double _sumdiv = rowtotal(p601t p602t p603t p604t p605t p606t p607t p608t p609t p610t p611t p612t)
gen double _gap = abs(_sumdiv - p600t)
quietly summarize _gap
di as text "Max |p600t - sum(p601t..p612t)| = " as result %9.4f r(max)
assert _gap < 0.6
drop _sumdiv _gap

* >>> ASSUMPTION [A1]: published p600t is the consumption measure
* >>> ASSUMPTION [A2]: annual = weekly x `weeks_per_year', nominal GBP
gen double cons_week   = p600t
gen double cons_annual = p600t * `weeks_per_year'

local i = 1
foreach d of local divs {
    local nm : word `i' of `names'
    gen double c_`nm' = p`d't * `weeks_per_year'
    local ++i
}

**# FIX [A11]: housing benefit add-back - computation
foreach v in b010 b020 b230 p257 {
    replace `v' = 0 if missing(`v')
}
gen double _netrent = b010 + b020
quietly count if _netrent != 0 | p257 != 0 | b230 != 0
local nrent = r(N)
quietly count if (_netrent != 0 | p257 != 0 | b230 != 0) & ///
    abs(_netrent + b230 - p257) < 0.02
di as text "Renters with net rent + b230 = gross rent p257: " ///
   as result %5.1f 100*r(N)/`nrent' "%"
quietly count if _netrent < 0
di as text "Households with negative net rent (b230 > rent): " as result r(N)

gen double cons_annual_pub = cons_annual
gen double hb_annual       = b230 * `weeks_per_year'
if `add_back_hb' {
    replace cons_week   = cons_week + b230
    replace cons_annual = cons_week * `weeks_per_year'
    replace c_housing   = c_housing + hb_annual
}
* the divisions still add up to the total after the add-back
egen double _sumdiv = rowtotal(c_*)
assert abs(_sumdiv - cons_annual) < 0.6 * `weeks_per_year'
drop _sumdiv _netrent b010 b020 b230 p257
**# END FIX [A11]

* Not consumption, kept for reference. 2024-25: mortgage interest (b150p) is
* suppressed for many mortgagors in the public file, so p620tp is unreliable.
gen double noncons_annual  = p620tp * `weeks_per_year'
gen double totexp_annual   = p630tp * `weeks_per_year'

* >>> ASSUMPTION [A7]: keep negative consumption, flag it
gen byte neg_cons = cons_annual < 0

rename a049 hhsize
drop p600t p601t p602t p603t p604t p605t p606t p607t p608t p609t p610t p611t p612t p620tp p630tp a055

*------------------------------------------------------------------------------
* Labels
*------------------------------------------------------------------------------
label define sy 2011 "2011" 2012 "2012" 2013 "2013" 2014 "2014" ///
    2015 "2015-16" 2016 "2016-17" 2017 "2017-18" 2018 "2018-19" ///
    2019 "2019-20" 2020 "2020-21" 2021 "2021-22" 2022 "2022-23" ///
    2023 "2023-24" 2024 "2024-25"
label values survey_year sy
label define gor 1 "North East" 2 "North West" 3 "Yorkshire and the Humber" ///
    4 "East Midlands" 5 "West Midlands" 6 "East" 7 "London" 8 "South East" ///
    9 "South West" 10 "Wales" 11 "Scotland" 12 "Northern Ireland"
label values gorx gor

label var hhid          "Household id, unique in pool (SN*100000 + case)"
label var sn            "UKDS study number of the release"
label var case          "LCF case number (unique within release)"
label var survey_year   "LCF survey year (first calendar year of release)"
label var q1_2015       "Jan-Mar 2015 household from separate 2015q1 file"
label var int_year      "Calendar year of interview"
label var int_quarter   "Calendar quarter of interview (a099)"
label var int_month     "Calendar month of interview (a055, reissues recoded)"
label var reissue       "Reissued case (a055 codes 21-32)"
label var gorx          "Government Office Region (gorx)"
label var hhsize        "Household size (a049)"
label var wt_annual     "Annual grossing weight, '000 hh (weighta / cal_weight_annual)"
label var wt_quarter    "Quarterly grossing weight (weightq / cal_weight_quarterly)"
label var cons_week     "Consumption, GBP/week, nominal (p600t)"
label var cons_annual   "Consumption, GBP/year, nominal (p600t x `weeks_per_year')"
label var c_food        "01 Food & non-alcoholic drinks, GBP/yr (p601t)"
label var c_alctob      "02 Alcohol, tobacco & narcotics, GBP/yr (p602t)"
label var c_clothing    "03 Clothing & footwear, GBP/yr (p603t)"
label var c_housing     "04 Housing (net), fuel & power, GBP/yr (p604t)"
label var c_furnish     "05 Furnishings & household equipment, GBP/yr (p605t)"
label var c_health      "06 Health, GBP/yr (p606t)"
label var c_transport   "07 Transport, GBP/yr (p607t)"
label var c_comms       "08 Communication, GBP/yr (p608t)"
label var c_recreation  "09 Recreation & culture, GBP/yr (p609t)"
label var c_education   "10 Education, GBP/yr (p610t)"
label var c_resthotel   "11 Restaurants & hotels, GBP/yr (p611t)"
label var c_misc        "12 Misc goods & services, GBP/yr (p612t)"
label var noncons_annual "Non-consumption expenditure, GBP/yr (p620tp); NOT consumption"
label var totexp_annual "Total expenditure, GBP/yr (p630tp = p600t + p620tp)"
label var neg_cons      "Negative total consumption (refunds/sales exceed spending)"

order hhid sn case survey_year q1_2015 int_year int_quarter int_month reissue ///
      gorx hhsize wt_annual wt_quarter cons_week cons_annual c_* ///
      noncons_annual totexp_annual neg_cons
**# FIX [A11]: housing benefit add-back - labels
local hbtxt = cond(`add_back_hb', " + b230", "")
local hstxt = cond(`add_back_hb', "gross of HB", "net of HB")
label var cons_week     "Consumption, GBP/week, nominal (p600t`hbtxt')"
label var cons_annual   "Consumption, GBP/year, nominal ((p600t`hbtxt') x `weeks_per_year')"
label var c_housing     "04 Housing (rent `hstxt'), fuel & power, GBP/yr (p604t`hbtxt')"
label var cons_annual_pub "Published ONS consumption, GBP/year (p600t x `weeks_per_year'), net of HB"
label var hb_annual     "Housing benefit / rent rebate, GBP/year (b230 x `weeks_per_year')"
order cons_annual_pub hb_annual, after(c_misc)
**# END FIX [A11]
sort survey_year hhid
compress

label data "LCF 2011-2024/25, household annual consumption (p600t x `weeks_per_year'), nominal GBP"
notes: Built by build_lcf_consumption.do on `c(current_date)'.
notes: Consumption = published p600t; see uk-lcf-consumption/README.md.
notes: England only = `england_only'; Jan-Mar 2015 included = `include_2015q1'.
notes: Breaks: 2013 housing/transport, 2018-19 communication/recreation, 2020-21 COVID.
**# FIX [A11]: housing benefit add-back - dataset label and note
label data "LCF 2011-2024/25, household annual consumption ((p600t`hbtxt') x `weeks_per_year'), nominal GBP"
notes: Housing benefit (b230) added back to rent = `add_back_hb'; published p600t in cons_annual_pub.
**# END FIX [A11]

save "$LCF_OUT", replace

*------------------------------------------------------------------------------
* Summary to the shell
*------------------------------------------------------------------------------
di _n as result "Households (N) and weighted mean annual consumption (nominal GBP)"
tabstat cons_annual [aw=wt_annual], by(survey_year) stat(n mean) format(%9.0fc) nototal
**# FIX [A11]: housing benefit add-back - summary
tabstat cons_annual cons_annual_pub hb_annual [aw=wt_annual], by(survey_year) ///
    stat(mean) format(%9.0fc) nototal
**# END FIX [A11]
quietly count if neg_cons
di as text "Households with negative consumption: " as result r(N)
di as text "Saved: $LCF_OUT  (" as result _N as text " rows)"
