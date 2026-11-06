*-------------------------------------------------------------------------------
* manuscript_numbers.do
*
* Reproduces every number in the manuscript's sector-mix (Maryland, Nevada) and
* partner-mix (California, Texas) paragraphs, October 2025. Each line prints the
* value as written in the text next to the value computed from the data.
*
* Input: one row per state x partner x HS6.
*   state     str   postal code. Keep PR, VI and XX: the national rates use every code.
*   cty_code  str   Census partner code (codes used below are set in section 0)
*   hs6       str6  HS6 code
*   imports   num   imports for consumption, USD
*   tau       num   national effective rate on the HS6 x partner cell
*                   (DataWeb calculated duty / customs value, as a decimal)
* If the file also has year and month, only October 2025 is kept.
*
*   do manuscript_numbers.do "path/to/panel.dta"
*
* Method. National sector rate t_h = national duty / national imports in HS6 h, which
* equals sum_c A_hc T_hc. National partner rate t_c = national duty / national imports
* from partner c, which equals sum_h B_hc T_hc. A state's sector-margin rate is
* tau_SM = sum_h h_h t_h and its partner-margin rate tau_PM = sum_c c_c t_c, where h and
* c are its sector and partner import shares. The "national rate" on a group of HS6
* codes for a state is sum_{h in group} h_h t_h / sum_{h in group} h_h.
*-------------------------------------------------------------------------------
version 18
clear all
set more off
set linesize 120
args panel
use "`panel'", clear

*--- 0. Setup -----------------------------------------------------------------
* Census partner codes
local CHINA   "5700"
local VIETNAM "5520"
local JAPAN   "5880"
local KOREA   "5800"
local MEXICO  "2010"
local CANADA  "1220"

capture confirm variable year month
if !_rc keep if year == 2025 & month == 10

gen double duty = imports*tau
gen hs2 = substr(hs6, 1, 2)
gen hs4 = substr(hs6, 1, 4)

* National rate on each HS6 (t_h) and each partner (t_c), from every state code
bysort hs6: egen double Dh = total(duty)
bysort hs6: egen double Mh = total(imports)
gen double t_h = Dh/Mh
bysort cty_code: egen double Dc = total(duty)
bysort cty_code: egen double Mc = total(imports)
gen double t_c = Dc/Mc

* Each row's share of its state's imports; within a state these terms sum to
* tau_SM, tau_PM and the actual rate
bysort state: egen double Ms = total(imports)
gen double sh     = imports/Ms
gen double sm_trm = sh*t_h
gen double pm_trm = sh*t_c
gen double ac_trm = sh*tau

* Print one number: label, value as written in the text, then the expression to compute
capture program drop show
program define show
    gettoken label 0 : 0
    gettoken text  0 : 0
    display as text %-58s "`label'" "  text " %9s "`text'" "   data " as result %7.2f `0'
end

* Share (percent) of a state's imports in the rows satisfying cond -> r(share)
capture program drop stshare
program define stshare, rclass
    args st cond
    quietly summarize sh if state == "`st'" & (`cond'), meanonly
    return scalar share = 100*r(sum)
end

* National rate (percent) on a state's own HS6 mix within cond -> r(rate)
capture program drop strate
program define strate, rclass
    args st cond
    quietly summarize sh     if state == "`st'" & (`cond'), meanonly
    local s = r(sum)
    quietly summarize sm_trm if state == "`st'" & (`cond'), meanonly
    return scalar rate = 100*r(sum)/`s'
end

* Share of national imports (percent) and national rate (percent) in cond
capture program drop usgroup
program define usgroup, rclass
    args cond
    quietly summarize imports, meanonly
    local tot = r(sum)
    quietly summarize imports if `cond', meanonly
    local m = r(sum)
    quietly summarize duty if `cond', meanonly
    return scalar share = 100*`m'/`tot'
    return scalar rate  = 100*r(sum)/`m'
end

* HS and partner groups
local CARS    `"hs4 == "8703""'
local METALS  `"inlist(hs2, "72", "73", "74", "76")"'
local HANDL   `"inlist(hs4, "8426", "8427", "8428", "8429", "8430", "8431")"'
local APPAREL `"inlist(hs2, "42", "61", "62", "63", "64", "94", "95")"'
local ENERGY  `"hs2 == "27""'
local PHARMA  `"hs2 == "30""'
local COMPUT  `"inlist(hs4, "8471", "8473")"'
local EPC     `"inlist(hs2, "27", "30") | inlist(hs4, "8471", "8473")"'
local ELEC    `"inlist(hs4, "8471", "8473", "8517", "8541", "8542", "8523")"'
local SERVERS `"inlist(hs6, "847150", "847180")"'
local NETWORK `"inlist(hs4, "8517", "8541", "8542", "8523")"'
local MACH    `"inlist(hs2, "84", "85")"'
local ASIA4   `"inlist(cty_code, "`CHINA'", "`VIETNAM'", "`JAPAN'", "`KOREA'")"'
local NAFTA   `"inlist(cty_code, "`MEXICO'", "`CANADA'")"'

*--- 1. State rates and standard deviations -----------------------------------
quietly summarize duty, meanonly
local D = r(sum)
quietly summarize imports, meanonly
scalar US = 100*`D'/r(sum)

preserve
collapse (sum) SM=sm_trm PM=pm_trm ACT=ac_trm, by(state)
foreach v in SM PM ACT {
    quietly replace `v' = 100*`v'
    foreach s in MD NV CA TX {
        quietly summarize `v' if state == "`s'", meanonly
        scalar `v'_`s' = r(mean)
    }
    quietly summarize `v' if !inlist(state, "PR", "VI", "XX")
    scalar sd_`v' = r(sd)
}
restore

*--- 2. Sector mix: Maryland and Nevada ---------------------------------------
display as text _n "{hline 100}" _n "Sector mix: Maryland and Nevada" _n "{hline 100}"

* National effective tariff rate, October 2025: all US duties / all US imports (%)
show "National effective rate"                          "10.8"  US
* Maryland sector-margin rate, tau_SM = sum_h h_h t_h (%)
show "Maryland sector-margin rate"                      "17.1"  SM_MD
* Nevada sector-margin rate, tau_SM (%)
show "Nevada sector-margin rate"                        "5.2"   SM_NV

* Share of Maryland's imports in passenger cars, HS4 8703 (%)
stshare MD `"`CARS'"'
show "MD passenger cars, share (8703)"                  "32"    r(share)
* National rate on passenger cars, weighted by Maryland's HS6 mix within 8703 (%)
strate MD `"`CARS'"'
show "MD passenger cars, national rate"                 "17.8"  r(rate)
* Share of Maryland's imports in steel, aluminum and copper, HS2 72, 73, 74, 76 (%)
stshare MD `"`METALS'"'
show "MD steel, aluminum, copper, share (72-74, 76)"   "6"     r(share)
* National rate on steel, aluminum and copper, weighted by Maryland's HS6 mix (%)
strate MD `"`METALS'"'
show "MD steel, aluminum, copper, national rate"        "32.8"  r(rate)
* Share of Maryland's imports in construction and materials-handling equipment,
* HS4 8426-8431 (%). This broad group is the manuscript's 5.0%; excavators, loaders
* and forklifts alone (842952, 842951, 842720) are 4.05%.
stshare MD `"`HANDL'"'
show "MD construction/handling equip., share (8426-31)" "5.0"   r(share)
* National rate on forklifts not electric (HS6 842720), over all partners (%)
quietly summarize t_h if hs6 == "842720", meanonly
show "National rate, forklifts (842720)"                "28-36" 100*r(mean)
* National rate on front-end shovel loaders (HS6 842951), over all partners (%)
quietly summarize t_h if hs6 == "842951", meanonly
show "National rate, front-end loaders (842951)"        "28-36" 100*r(mean)
* National rate on excavators and shovel loaders (HS6 842952), over all partners (%)
quietly summarize t_h if hs6 == "842952", meanonly
show "National rate, excavators (842952)"               "28-36" 100*r(mean)
* Share of Maryland's imports in apparel, footwear, furniture and toys,
* HS2 42, 61, 62, 63, 64, 94, 95 (%)
stshare MD `"`APPAREL'"'
show "MD apparel, footwear, furniture, toys, share"     "5"     r(share)
* National rate on those goods, weighted by Maryland's HS6 mix (%)
strate MD `"`APPAREL'"'
show "MD apparel, footwear, furniture, toys, rate"      "27.3"  r(rate)
* National rate on energy, HS2 27, on the national mix (%)
usgroup `"`ENERGY'"'
show "National rate, energy (27)"                       "<1"    r(rate)
* National rate on pharmaceuticals, HS2 30, on the national mix (%)
usgroup `"`PHARMA'"'
show "National rate, pharmaceuticals (30)"              "<1"    r(rate)
* National rate on computers, HS4 8471, 8473, on the national mix (%)
usgroup `"`COMPUT'"'
show "National rate, computers (8471, 8473)"            "<1"    r(rate)
* Share of Maryland's imports in energy, pharmaceuticals and computers combined (%)
stshare MD `"`EPC'"'
show "MD energy + pharma + computers, share"            "2"     r(share)
* Share of national imports in energy, pharmaceuticals and computers combined (%)
usgroup `"`EPC'"'
show "US energy + pharma + computers, share"            "25"    r(share)

* Share of Nevada's imports in computers and other electronics,
* HS4 8471, 8473, 8517, 8541, 8542, 8523 (%)
stshare NV `"`ELEC'"'
show "NV computers and other electronics, share"        "75.1"  r(share)
* Share of Nevada's imports in servers and data-processing units, HS6 847150, 847180 (%)
stshare NV `"`SERVERS'"'
show "NV servers, data-processing units (847150/80)"    "53"    r(share)
* Share of Nevada's imports in network equipment, processors and storage,
* HS4 8517, 8541, 8542, 8523 (%)
stshare NV `"`NETWORK'"'
show "NV network, processors, storage, share"           "19"    r(share)
* National rate on computers (HS4 8471, 8473), weighted by Nevada's HS6 mix (%)
strate NV `"`COMPUT'"'
show "NV computers, national rate"                      "<2"    r(rate)
* National rate on network equipment, processors and storage, weighted by
* Nevada's HS6 mix (%)
strate NV `"`NETWORK'"'
show "NV network, processors, storage, national rate"   "<2"    r(rate)
* National rate on servers (HS6 847150), over all partners (%)
quietly summarize t_h if hs6 == "847150", meanonly
show "National rate, servers (847150)"                  "0.2"   100*r(mean)

*--- 3. Partner mix: California and Texas -------------------------------------
display as text _n "{hline 100}" _n "Partner mix: California and Texas" _n "{hline 100}"

* Share of California's imports in machinery and electrical equipment, HS2 84, 85 (%)
stshare CA `"`MACH'"'
show "CA machinery and electrical, share (84-85)"       "59"    r(share)
* Share of Texas's imports in machinery and electrical equipment, HS2 84, 85 (%)
stshare TX `"`MACH'"'
show "TX machinery and electrical, share (84-85)"       "52"    r(share)
* California sector-margin rate, tau_SM (%)
show "California sector-margin rate"                    "10.5"  SM_CA
* Texas sector-margin rate, tau_SM (%)
show "Texas sector-margin rate"                         "9.5"   SM_TX
* California partner-margin rate, tau_PM = sum_c c_c t_c (%)
show "California partner-margin rate"                   "13.9"  PM_CA
* Texas partner-margin rate, tau_PM (%)
show "Texas partner-margin rate"                        "8.3"   PM_TX

* Share of California's imports from China, Vietnam, Japan and South Korea combined (%)
stshare CA `"`ASIA4'"'
show "CA China + Vietnam + Japan + Korea, share"        ">40"   r(share)
* Share of California's imports from Vietnam (%)
stshare CA `"cty_code == "`VIETNAM'""'
show "CA share from Vietnam"                            "15.9"  r(share)
* Share of California's imports from China (%)
stshare CA `"cty_code == "`CHINA'""'
show "CA share from China"                              "15.5"  r(share)
* Share of California's imports from Japan and South Korea combined (%)
stshare CA `"inlist(cty_code, "`JAPAN'", "`KOREA'")"'
show "CA Japan + Korea, share"                          "9.2"   r(share)
* Share of California's imports from Japan (%)
stshare CA `"cty_code == "`JAPAN'""'
show "CA share from Japan"                              "4.6"   r(share)
* Share of California's imports from South Korea (%)
stshare CA `"cty_code == "`KOREA'""'
show "CA share from South Korea"                        "4.6"   r(share)
* National effective rate on imports from Vietnam, over all products (%):
* bottom of the manuscript's 12.4-37.8% range
quietly summarize t_c if cty_code == "`VIETNAM'", meanonly
show "National rate on Vietnam"                         "12.4"  100*r(mean)
* National effective rate on imports from South Korea, over all products (%)
quietly summarize t_c if cty_code == "`KOREA'", meanonly
show "National rate on South Korea"                     "12.4-37.8" 100*r(mean)
* National effective rate on imports from Japan, over all products (%)
quietly summarize t_c if cty_code == "`JAPAN'", meanonly
show "National rate on Japan"                           "12.4-37.8" 100*r(mean)
* National effective rate on imports from China, over all products (%):
* top of the 12.4-37.8% range
quietly summarize t_c if cty_code == "`CHINA'", meanonly
show "National rate on China"                           "37.8"  100*r(mean)

* Share of Texas's imports from China, Vietnam, Japan and South Korea combined (%)
stshare TX `"`ASIA4'"'
show "TX China + Vietnam + Japan + Korea, share"        "13.1"  r(share)
* Share of Texas's imports from Mexico (%)
stshare TX `"cty_code == "`MEXICO'""'
show "TX share from Mexico"                             "45.8"  r(share)
* Share of Texas's imports from Canada (%)
stshare TX `"cty_code == "`CANADA'""'
show "TX share from Canada"                             "8.0"   r(share)
* National effective rate on imports from Mexico, over all products (%)
quietly summarize t_c if cty_code == "`MEXICO'", meanonly
show "National rate on Mexico"                          "4.4"   100*r(mean)
* National effective rate on imports from Canada, over all products (%)
quietly summarize t_c if cty_code == "`CANADA'", meanonly
show "National rate on Canada"                          "3.8"   100*r(mean)
* Share of California's imports from Mexico and Canada combined (%)
stshare CA `"`NAFTA'"'
show "CA Mexico + Canada, share"                        "14.5"  r(share)
* Share of Texas's imports from Mexico and Canada combined (%)
stshare TX `"`NAFTA'"'
show "TX Mexico + Canada, share"                        "53.8"  r(share)

*--- 4. Comparison -------------------------------------------------------------
display as text _n "{hline 100}" _n "Comparison" _n "{hline 100}"

* California minus Texas partner-margin rate (percentage points)
show "CA - TX partner-margin gap"                       "5.6"   PM_CA - PM_TX
* Maryland minus Nevada sector-margin rate (percentage points)
show "MD - NV sector-margin gap"                        "11.9"  SM_MD - SM_NV
* MD-NV sector gap divided by CA-TX partner gap: "more than double"
show "Ratio, sector gap / partner gap"                  ">2"    (SM_MD - SM_NV)/(PM_CA - PM_TX)
* Standard deviation of the actual effective rate across the 50 states + DC
* (sample SD, states unweighted, percentage points)
show "SD across 50 states + DC, actual rate"            "4.4"   sd_ACT
* Standard deviation of the sector-margin rate across the 50 states + DC
show "SD across 50 states + DC, sector-margin rate"     "3.9"   sd_SM
* Standard deviation of the partner-margin rate across the 50 states + DC
show "SD across 50 states + DC, partner-margin rate"    "2.2"   sd_PM
