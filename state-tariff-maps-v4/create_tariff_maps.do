//------------------------------------------------------------------------------
* AUTHOR: SAM MOORE 
* DATE: 10/15/2026
* PURPOSE: compute effective tariffs for each state 
//------------------------------------------------------------------------------

global ROOT = "C:\Users\G1SAM03\FRBC Dropbox\Sam Moore\tariff_states"
global SHP = "$ROOT\data"
global RAW = "$ROOT\out"
global FIG = "$ROOT\figures"

cap mkdir "$FIG"

*ssc install shp2dta 
*ssc install spmap 

//------------------------------------------------------------------------------
* Need to make a crosswalk (shit) 
//------------------------------------------------------------------------------

tempfile cross

import excel "$RAW\schedule_c.xlsx", clear 
keep A B 
ren B country
ren A cty_code
drop if mi(cty_code)

save `cross', replace 

//------------------------------------------------------------------------------
* Import Tariff Data 
//------------------------------------------------------------------------------

tempfile tariffs

import delimited "$RAW\effective_tariffs_hs6.csv", clear 

* fix hs6 

tostring hs6, replace 
replace hs6 = "0" + hs6 if strlen(hs6) == 5 

* make date 

gen date = ym(year, month)
format date %tm 
drop customs_value_usd calc_duty_usd year month

* fix country 

merge m:1 country using `cross'

* some manual fixes 

replace cty_code = 6024 if country == "Christmas Island"
replace cty_code = 4351 if country == "Czechia (Czech Republic)"
replace cty_code = 2777 if country == "CuraÃ§ao"
replace cty_code = 7480 if country == "CÃ´te d`Ivoire"
replace cty_code = 7660 if country == "Democratic Republic of the Congo"
replace cty_code = 4099 if country == "Denmark"
replace cty_code = 7950 if country == "Eswatini (Swaziland)"
replace cty_code = 3720 if country == "Falkland Islands"
replace cty_code = 5082 if country == "Gaza Strip"
replace cty_code = 4280 if country == "Germany"
replace cty_code = 6029 if country == "Heard and McDonald Islands"
replace cty_code = 5530 if country == "Laos"
replace cty_code = 5660 if country == "Macau"
replace cty_code = 6820 if country == "Micronesia"
replace cty_code = 4641 if country == "Moldova"
replace cty_code = 2485 if country == "Montserrat "
replace cty_code = 5460 if country == "Myanmar (Burma)"
replace cty_code = 6862 if country == "Nauru"
replace cty_code = 7630 if country == "Republic of the Congo"
replace cty_code = 6150 if country == "Samoa"
replace cty_code = 5800 if country == "South Korea"
replace cty_code = 5020 if country == "Syria"
replace cty_code = 7644 if country == "SÃ£o TomÃ© and PrÃ­ncipe"
replace cty_code = 7830 if country == "Tanzania"
replace cty_code = 4752 if country == "Vatican City"
replace cty_code = 5083 if country == "West Bank"
replace cty_code = 5210 if country == "Yemen"

count if _merge == 1 & mi(cty_code)
drop if _merge == 2
drop _merge country 

* save 

save `tariffs', replace 

//------------------------------------------------------------------------------
* Import State, Country, Sector trade data 
//------------------------------------------------------------------------------

import delimited "$RAW/state_imports_hs6.csv", clear 

* fix hs6 

tostring hs6, replace 
replace hs6 = "0" + hs6 if strlen(hs6) == 5 

* make date 

gen date = ym(year, month)
format date %tm 
drop year month value_usd air_val_usd ves_val_usd cnt_val_usd

* fix country 

merge m:1 cty_code using `cross'
drop if _merge == 2 
drop _merge 

* merge in effective tariffs 

merge m:1 cty_code hs6 date using `tariffs'
drop _merge 

* for now, assume that missing (6788/9000000 + cases) implies no tariff 

replace effective_rate = 0 if mi(effective_rate)

save "$RAW\tariff_sector_state", replace 

//------------------------------------------------------------------------------
* Find effective rate by state overtime
//------------------------------------------------------------------------------

preserve 

	tempfile sum

	collapse (sum) con_val_usd, by(state date)

	save `sum', replace 
	
restore 	

collapse (mean) effective_rate [aw = con_val_usd], by(state date)

merge 1:1 state date using `sum', nogen 

save "$RAW\weighted_by_state.dta", replace 


//------------------------------------------------------------------------------
* State GDP data 
//------------------------------------------------------------------------------

tempfile state_GDP

import delimited "$SHP/state_GDP.csv", clear
drop if _n <= 4 
keep v2 v6 
ren (v2 v6) (state Q4_GDP)
destring Q4_GDP, replace 

drop if _n == 1 | _n > 52 

gen state_abbrev = ""

* AI crosswalk 

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

save `state_GDP', replace 
//------------------------------------------------------------------------------
* Make some Maps
//------------------------------------------------------------------------------

use "$RAW\weighted_by_state.dta", clear
export delimited "$RAW\weighted_by_state.csv", replace

* run once
*shp2dta using "$SHP/cb_2018_us_state_20m.shp", database("$SHP/statedb") coordinates("$SHP/statecoord") genid(id)

tempfile statedb_clean centroids prep mapcoord

//------------------------------------------------------------------------------
* Shapefile database -> state/id crosswalk (+ grab AK / HI ids)
//------------------------------------------------------------------------------

use "$SHP\statedb.dta", clear
ren STUSPS state
levelsof id if state == "AK", local(id_ak) clean
levelsof id if state == "HI", local(id_hi) clean
keep state id
save "`statedb_clean'.dta", replace 

//------------------------------------------------------------------------------
* Build a mapping-only coordinate file with AK and HI as insets
*   - source file is NOT overwritten, so this is safe to re-run
//------------------------------------------------------------------------------

* where the insets go (lon, lat of inset center) and how much to shrink
local ak_s   0.35
local ak_cx -116
local ak_cy  27
local hi_s   1.00
local hi_cx -104
local hi_cy  26

use "$SHP\statecoord.dta", clear

* AK: Aleutians cross the dateline -> pull them back to negative longitude
replace _X = _X - 360 if _X > 0 & _ID == `id_ak'

* shrink around bounding-box center, then translate to inset location
foreach st in ak hi {
    qui sum _X if _ID == `id_`st''
    local x0 = (r(min) + r(max))/2
    qui sum _Y if _ID == `id_`st''
    local y0 = (r(min) + r(max))/2
    replace _X = (_X - `x0')*``st'_s' + ``st'_cx' if _ID == `id_`st''
    replace _Y = (_Y - `y0')*``st'_s' + ``st'_cy' if _ID == `id_`st''
}

save "`mapcoord'.dta", replace

//------------------------------------------------------------------------------
* Label anchors (bounding-box midpoints) from the *mapping* coordinate file
//------------------------------------------------------------------------------

drop if mi(_X) | mi(_Y)
collapse (min) xmin=_X ymin=_Y (max) xmax=_X ymax=_Y, by(_ID)
gen cx = (xmin + xmax)/2
gen cy = (ymin + ymax)/2
ren _ID id
keep id cx cy
save "`centroids'.dta", replace 

//------------------------------------------------------------------------------
* Prep mapping data (everything the maps need lives in this file)
//------------------------------------------------------------------------------

use "$RAW\weighted_by_state.dta", clear

merge m:1 state using "`statedb_clean'.dta"
drop if _merge == 2
drop _merge

* keep AK and HI now; only drop territories / unknown
drop if inlist(state, "XX", "PR", "VI")

merge m:1 id using "`centroids'.dta"
drop if _merge == 2
drop _merge

replace effective_rate = effective_rate*100

* label anchors at each state's widest section: among label-height (0.9 deg)
* horizontal bands, take those within ~5% of the state's widest inside span,
* centre the label vertically in that run and horizontally in the span
* (MI: its single widest band). Computed from cb_2018_us_state_20m.
replace cx = -120.5  if state == "WA"
replace cy = 47.1    if state == "WA"
replace cx = -120.6  if state == "OR"
replace cy = 43.1    if state == "OR"
replace cx = -118.0  if state == "CA"
replace cy = 35.1    if state == "CA"
replace cx = -117.0  if state == "NV"
replace cy = 40.4    if state == "NV"
replace cx = -114.0  if state == "ID"
replace cy = 43.2    if state == "ID"
replace cx = -109.9  if state == "MT"
replace cy = 48.1    if state == "MT"
replace cx = -107.6  if state == "WY"
replace cy = 43.0    if state == "WY"
replace cx = -111.6  if state == "UT"
replace cy = 39.0    if state == "UT"
replace cx = -111.8  if state == "AZ"
replace cy = 35.2    if state == "AZ"
replace cx = -106.0  if state == "NM"
replace cy = 34.5    if state == "NM"
replace cx = -105.6  if state == "CO"
replace cy = 39.0    if state == "CO"
replace cx = -100.5  if state == "ND"
replace cy = 47.2    if state == "ND"
replace cx = -100.3  if state == "SD"
replace cy = 44.3    if state == "SD"
replace cx = -100.2  if state == "NE"
replace cy = 41.8    if state == "NE"
replace cx = -98.3   if state == "KS"
replace cy = 38.2    if state == "KS"
replace cx = -97.3   if state == "OK"
replace cy = 35.7    if state == "OK"
replace cx = -99.5   if state == "TX"
replace cy = 31.2    if state == "TX"
replace cx = -94.1   if state == "MN"
replace cy = 47.6    if state == "MN"
replace cx = -93.4   if state == "IA"
replace cy = 42.1    if state == "IA"
replace cx = -92.1   if state == "MO"
replace cy = 37.2    if state == "MO"
replace cx = -92.4   if state == "AR"
replace cy = 35.6    if state == "AR"
replace cx = -90.3   if state == "WI"
replace cy = 45.3    if state == "WI"
replace cx = -89.4   if state == "IL"
replace cy = 40.2    if state == "IL"
replace cx = -84.4   if state == "MI"
replace cy = 43.1    if state == "MI"
replace cx = -85.6   if state == "KY"
replace cy = 37.2    if state == "KY"
replace cx = -86.6   if state == "TN"
replace cy = 36.0    if state == "TN"
replace cx = -78.9   if state == "NC"
replace cy = 35.7    if state == "NC"
replace cx = -76.2   if state == "NY"
replace cy = 42.6    if state == "NY"
replace cx = -77.9   if state == "PA"
replace cy = 40.9    if state == "PA"
replace cx = -91.7   if state == "LA"
replace cy = 30.4    if state == "LA"

* leader states: point inside the state where the leader line starts
replace cx = -69.2   if state == "ME"
replace cy = 45.4    if state == "ME"
replace cx = -77.8   if state == "VA"
replace cy = 37.8    if state == "VA"
replace cx = -80.6   if state == "WV"
replace cy = 38.8    if state == "WV"
replace cx = -81.5   if state == "FL"
replace cy = 28.2    if state == "FL"
replace cx = -82.7   if state == "OH"
replace cy = 40.3    if state == "OH"
replace cx = -86.2   if state == "IN"
replace cy = 41.0    if state == "IN"

* insets: AK's bbox center sits in the Aleutians, so push label onto the mainland
replace cx = `ak_cx' + 3   if state == "AK"
replace cy = `ak_cy' + 1   if state == "AK"
replace cx = `hi_cx'       if state == "HI"
replace cy = `hi_cy' - 2.5 if state == "HI"   // just below the islands

* states too small or narrow for the larger labels: the label sits off the
* state and a leader line connects it to the state.
*   grp 1 = regular (centered on state)
*   grp 2 = text to the right of the anchor (Atlantic column, top row)
*   grp 3 = text below the anchor (bottom row, Gulf of Mexico)
*   grp 4 = text above the anchor
gen byte small = 0
gen byte grp   = 1
gen lx = .
gen ly = .
local k = 0
foreach s in ME VT NH MA RI CT NJ DE MD DC VA WV SC GA FL {
    replace small = 1               if state == "`s'"
    replace grp   = 2               if state == "`s'"
    replace lx    = -65.0           if state == "`s'"
    replace ly    = 46.0 - `k'*1.6  if state == "`s'"
    local ++k
}
* top row (Lake Superior / Ontario), text right of the anchor: IN, OH
* bottom row (Gulf of Mexico), text below the anchor: MS, AL
foreach spec in "IN 2 -85.4 48.6" "OH 2 -80.2 48.6" ///
                "MS 3 -89.4 27.4" "AL 3 -84.6 27.4" {
    tokenize `spec'
    replace small = 1   if state == "`1'"
    replace grp   = `2' if state == "`1'"
    replace lx    = `3' if state == "`1'"
    replace ly    = `4' if state == "`1'"
}

* optional bend point for a leader (missing = straight line). IN bends in
* Lake Michigan so its leader passes west of the MI label.
gen vx = .
gen vy = .
replace vx = -87.3 if state == "IN"
replace vy =  44.4 if state == "IN"

* where the label text is anchored
gen ax = cond(small, lx, cx)
gen ay = cond(small, ly, cy)

* make change relative to base month (Jan 2025)

gen temp = effective_rate if date == 780
bys state: egen baseline = min(temp)
drop temp 

gen delta_rate = effective_rate - baseline 

** add in state GDP 

merge m:1 state using `state_GDP'
drop if _merge == 2 
drop _merge 

** calculate tariff burden as a % of GDP 

gen temp = (effective_rate*(con_val_usd/1e6))/100 if date == 780
bys state: egen baseline_burden = min(temp)
drop temp 

gen implied_burden = ((con_val_usd/1e6)*effective_rate)/100 
gen delta_burden = implied_burden - baseline_burden 

gen delta_burden_pGDP = ((delta_burden)/(Q4_GDP/12))*100 // annualized to monthly 

keep if date == 789 

save "`prep'.dta", replace 

//------------------------------------------------------------------------------
* Map-drawing program (one call per variable)
//------------------------------------------------------------------------------

cap program drop draw_state_map
program define draw_state_map
    syntax varname, prepfile(string) coordfile(string) breaks(string) ///
                    legtitle(string) maptitle(string) outfile(string) name(string)

    tempfile month labels leaders

    * ---- this map's data ------------------------------------------------
    use "`prepfile'", clear
    gen labtxt = state + " " + string(`varlist', "%4.1f")
    save "`month'.dta", replace 

    * ---- label file -----------------------------------------------------
    keep ax ay labtxt grp
    save "`labels'.dta", replace 

    * ---- leader lines: state point -> (bend) -> offshore label anchor ----
    * polyline format: _ID _X _Y, pieces separated by a row of missings;
    * without a bend point the middle vertex repeats the start (straight line)
    use "`month'.dta" if small == 1, clear
    keep cx cy lx ly vx vy
    replace vx = cx if mi(vx)
    replace vy = cy if mi(vy)
    gen _ID = _n
    expand 4
    bys _ID: gen pt = _n
    gen _X = cond(pt == 1, cx, cond(pt == 2, vx, cond(pt == 3, lx, .)))
    gen _Y = cond(pt == 1, cy, cond(pt == 2, vy, cond(pt == 3, ly, .)))
    keep _ID _X _Y
    sort _ID
    save "`leaders'.dta", replace 

    * ---- fill colours -----------------------------------------------------
    * light yellow-green-blue ramp: even the darkest class keeps black
    * labels readable (contrast with black >= ~4.7:1). With fewer than 9
    * classes, colours are taken evenly spaced from the ramp.
    local ramp `""255 255 217" "225 243 197" "194 231 180" "159 217 184" "123 204 188" "88 191 193" "56 173 195" "40 155 194" "38 125 185""'
    local nclass = wordcount("`breaks'") - 1
    local fcols ""
    forvalues k = 1/`nclass' {
        local j = cond(`nclass' == 1, 1, round(1 + (`k' - 1)*8/(`nclass' - 1)))
        local c : word `j' of `ramp'
        local fcols `"`fcols' "`c'""'
    }

    * ---- draw -----------------------------------------------------------
    use "`month'.dta", clear

    spmap `varlist' using "`coordfile'", id(id)                          ///
        fcolor(`fcols') ocolor(gs5 ..) osize(vthin ..)                   ///
        clmethod(custom) clbreaks(`breaks') legorder(lohi)               ///
        label(data("`labels'.dta")                                       ///
              xcoord(ax) ycoord(ay) label(labtxt) by(grp)                ///
              size(medium medium medium medium)                         ///
              color(black black black black) position(0 3 6 12))        ///
        line(data("`leaders'.dta") color(gs6) size(vthin))               ///
        legend(position(6) row(1) ring(3) size(medium)                   ///
               symxsize(*1.4) symysize(*1.4) keygap(*1.6) colgap(*1.2)    ///
               title("`legtitle'", size(medlarge)))                       ///
        title("")                                                        ///
        note("Source: Authors' calculations. Alaska and Hawaii not to scale.", size(medlarge)) ///
        graphregion(margin(l=2 r=14)) name(`name', replace)

    graph export "`outfile'", replace 
end

//------------------------------------------------------------------------------
* Draw the maps
//------------------------------------------------------------------------------

draw_state_map delta_rate,                                            ///
    prepfile("`prep'.dta") coordfile("`mapcoord'.dta")                ///
    breaks(0 2 4 6 8 10 12 14 16 18)                                  ///
    legtitle("Increase in effective tariff (pp)")                                  ///
    maptitle("Increase in effective tariff rate between Jan. 2025 and Oct. 2025")                     ///
    outfile("$FIG\rate_heterogeneity.pdf") name(rate)

draw_state_map delta_burden_pGDP,                                     ///
    prepfile("`prep'.dta") coordfile("`mapcoord'.dta")                ///
    breaks(0 0.4 0.8 1.2 1.6 2.0 2.4 2.8)                             ///
    legtitle("Share of GDP (%)")                                      ///
    maptitle("Increase in implied tariff burden as a percentage of GDP between Jan. 2025 and Oct. 2025") ///
    outfile("$FIG\share_heterogeneity.pdf") name(burden)
	
//------------------------------------------------------------------------------
* Three-panel scatter: change in tariff burden (pp of GDP), Jan -> Oct 2025,
* against (A) the change in the actual effective rate, (B) the change in the
* partner-margin rate and (C) the change in the sector-margin rate (pp).
* Margins come from state-tariff-heterogeneity/scripts/counterfactual_margins.py
* (d_partner_only, d_product_only); put the CSV in $RAW.
//------------------------------------------------------------------------------

tempfile margins
import delimited "$RAW\state_counterfactual_margins_change_jan_oct2025.csv", clear
keep state d_partner_only d_product_only
save "`margins'", replace

use "`prep'.dta", clear
merge 1:1 state using "`margins'", keep(match) nogen
keep if !mi(delta_rate, d_partner_only, d_product_only, delta_burden_pGDP)

* ---- common axes for all three panels: start at 0, round tops --------------
local xmax = 0
foreach v in delta_rate d_partner_only d_product_only {
    qui sum `v'
    local xmax = max(`xmax', r(max))
}
local xtop = ceil(`xmax'/5)*5

qui sum delta_burden_pGDP
local ymax = r(max)
foreach v in delta_rate d_partner_only d_product_only {
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

burden_panel delta_rate,     xtitle("Change in actual effective rate (pp)") ///
    name(p_rate)    xtop(`xtop') ytop(`ytop') ystep(`ystep')
burden_panel d_partner_only, xtitle("Change in partner margin rate (pp)")   ///
    name(p_partner) xtop(`xtop') ytop(`ytop') ystep(`ystep')
burden_panel d_product_only, xtitle("Change in sector margin rate (pp)")    ///
    name(p_sector)  xtop(`xtop') ytop(`ytop') ystep(`ystep')

graph combine p_rate p_partner p_sector, rows(1) iscale(1) imargin(small)   ///
    xsize(16.5) ysize(5.5) graphregion(color(white))

graph export "$FIG\scatter_rate_burden.pdf", replace
