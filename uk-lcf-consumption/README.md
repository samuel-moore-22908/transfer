# UK Living Costs and Food Survey: household consumption, 2011 to 2024-25

How to build a household-level consumption measure from the 14 LCF releases (UKDS SN 7272 … 9603), which variables are aggregated in each release, and how well the published totals can be reproduced from their components. Scope: **England only** (`gorx` 1–9).

Everything below was checked in two ways: against the official documentation (Volume F Part 3 "Specification of product codes", the Family Spending specifications, and Volume I for 2023-24 and 2024-25), and against the microdata itself, by rebuilding every published total from its parts household by household.

## 1. Bottom line

- **Consumption = `p600t`** in the derived household file (`dvhh`). It is COICOP total consumption expenditure in £ per week for the whole household, including children aged 7–15.
- In every release, `p600t` is **exactly** `p601t + p602t + … + p612t`, one total per COICOP division (checked for every household; 2024-25 differs only by rounding, see §6).
- Total expenditure `p630tp` is **exactly** `p600t + p620tp` in every release. `p620tp` is non-consumption spending: mortgage interest, council tax, pension contributions, savings, life insurance, licences, money transfers, and so on. **Do not use `p630tp` as consumption.**
- The way the division totals are built is the same in all 14 releases, apart from a few documented breaks (§5). The biggest is the 2018-19 telecoms redesign.
- If you need the published measure, use `p600t` and `p601t`–`p612t` directly. If you need a custom measure, rebuild from the components listed in `data/consumption_components.csv`. The rebuilt totals match the published ones to within £0.20 per week per household on average (§6).

## 2. Which file to use in each release

| Survey year | SN | File (`stata/...`) | Household ID | Annual weight | England households |
|---|---|---|---|---|---|
| 2011 | 7272 | `2011_dvhh_ukanon.dta` | `case` | `weighta` | 4,779 |
| 2012 | 7472 | `2012_dvhh_ukanon.dta` | `case` | `weighta` | 4,673 |
| 2013 | 7702 | `2013_dvhh_ukanon.dta` | `case` | `weighta` | 4,335 |
| 2014 | 7992 | `2014_dvhh_ukanon.dta` | `case` | `weighta` | 4,325 |
| Jan–Mar 2015 | 8210 | `2015q1_dvhh_ukanon.dta` | `case1` | `weighta` | (bridge quarter) |
| 2015-16 | 8210 | `2015-16_dvhh_ukanon.dta` | `case` | `weighta` | 4,109 |
| 2016-17 | 8351 | `2016_17_dvhh_ukanon.dta` | `case` | `weighta` | 4,050 |
| 2017-18 | 8459 | `dvhh_ukanon_2017-18.dta` | `case` | `weighta` | 4,030 |
| 2018-19 | 8686 | `2018_dvhh_ukanon.dta` | `case` | `weighta` | 4,054 |
| 2019-20 | 8803 | `lcfs_2019_dvhh_ukanon.dta` | `case` | `weighta` | 4,033 |
| 2020-21 | 9022 | `lcfs_2020_dvhh_ukanon.dta` | `case` | `weighta` | 4,184 |
| 2021-22 | 9123 | `lcfs_2021_dvhh_ukanon.dta` | `case` | `weighta` | 4,261 |
| 2022-23 | 9335 | `dvhh_ukanon_2022.dta` | `case` | `weighta` | 3,288 |
| 2023-24 | 9468 | `dvhh_ukanon_v2_2023.dta` | `case` | `weighta` | 2,907 |
| 2024-25 | 9603 | **`dvhh_uk_anon_v3_2024.dta`** | `case` | **`cal_weight_annual`** | 3,644 |

Notes:
- Use the plain `dvhh` file, not the `urbanrural` variant (it is the same file plus two urban/rural variables).
- **2024-25:** use the **v3** file. The v2 file has no calibrated weights. ONS renamed `weighta`/`weightq` to `cal_weight_annual`/`cal_weight_quarterly`; the UKDS notes confirm they are the same weights.
- Weights: `weighta = weightq / 4`. The sum of `weighta` over a year is UK households in thousands. Restricting to England keeps England's share.
- **England:** `gorx` in 1–9 (1 North East, 2 North West, 3 Yorkshire and the Humber, 4 East Midlands, 5 West Midlands, 6 East, 7 London, 8 South East, 9 South West). The codes and labels are identical in all releases.
- Calendar years 2011–2014, financial years (April–March) from 2015-16. The Jan–Mar 2015 file fills the gap. Its totals reproduce with the 2015-16 formulas (all divisions 100% except housing, at 95.9%).
- Interview timing: `year` and `a055` (month; codes 21–32 are reissued cases, so subtract 20).
- `p601t` … `p612t`, `p600t`, `p620tp` and `p630tp` exist under the same names in every release.

## 3. How the variables are organised

Everything is in £ per week. Questionnaire amounts are converted to weekly equivalents; diary amounts are two-week totals divided by two.

**Suffixes** (Volume F explanatory notes):
- none: adults only
- `c`: children aged 7–15 only (from the youth diary)
- `t`: household total (adults plus children)
- `p`: anonymised version, released
- `u`: unanonymised, ONS only, **not** in the public data

**Prefixes:**
- `b…`: questionnaire amounts (rent, utility bills, insurance, vehicle purchases, and so on). These are household-level and have no adult/child split.
- `c…`: COICOP-plus item codes. `c` is followed by the COICOP code with the dots removed; divisions 10, 11, 12 and non-consumption appear as `ca`, `cb`, `cc` and `ck`. For example, `cc1312` is toiletries (12.1.3.1.02). These combine diary spending with some questionnaire items routed through table SET89 (Volume A and Volume D notes). Questionnaire items that are also recorded in the diary are dropped from SET89, so they are not counted twice.
- `p…`: derived totals.

**The general recipe for a household-total division `p6xxt`:**

```
p6xxt =   [questionnaire b-codes in the division]
        + [t-version of every adult c-code in the division]      (adults + children)
        + [child-only c-codes that have no adult counterpart]    (e.g. c71111c, cb1117c, ca1111c)
```

In the data, `c?????t = c????? + c?????c` for every consumption item code. (The exception is five `ck52xx` money-transfer codes in non-consumption.)

Two naming traps:
- Some **adult** codes end in a letter that looks like a suffix: `cb111c`, `cb111d` … `cb111j` are alcohol away from home, and `c9431c` is lottery winnings. `cb111c` is not a child code; its household total is `cb111ct`.
- `cb1311t` + `cb1312t` = `cb1111t` exactly, in every year. They are a food/drink split of catered food eaten on the premises. **Do not add them as well as `cb1111t`.**

## 4. What consumption (`p600t`) includes and excludes

**Included:**
- **Housing:** net rent (rent after housing benefit or rebates; `b010`, `b020`), service charges, water and sewerage, repairs and maintenance, and all domestic fuel.
- **Vehicle purchases:** outright purchases (`b244`, `b245`, `b247`) and loan- or HP-financed purchases (`c71112t`, `c71122t`, …).
- All durables, package holidays (`b480`, `b481`), gambling stakes (in 09.4.3), education fees (`b160`, `b164`) and children's own spending.

**Excluded** (in `p620tp` or not counted at all):
- **No imputed rent for owner-occupiers.** The LCF does not collect it.
- **Mortgage interest** (`b130`, `b150`) and **council tax** (`b030`, `b038p`): in non-consumption.
- **Purchase of dwellings, capital improvements, second homes:** non-consumption (`ck1211t`, `ck1411t`, `ck1315`, `p129t`).
- **Pension contributions, life insurance, savings and investments, income tax and NI, money transfers, licences and fines, holiday spending money:** non-consumption.
- **Gambling winnings** (`c9431*t`): recorded but not in any total.

Two other "totals" exist and are **not** consumption:
- `p550tp`: the old FES-style total expenditure (sum of the `p536`–`p549` ONS categories).
- Family Spending (Workbook 1, Table A1) "total expenditure": COICOP 1–12 plus category 13, "other expenditure items" (see Volume I sheet 13).

## 5. Variables aggregated in each release

Exact per-release lists, with signs and labels, are in **`data/consumption_components.csv`**. It has one row per (year, total, variable).

The `source` column says where each term comes from:
- `Volume F`: in the official formula.
- `empirical (not in Volume F)`: needed to reproduce the published total, but missing from the documentation.
- `in Volume F but NOT in public dvhh`: in the official formula, but the variable is not released.

### 5.1 How each division is built, and every change over time

The diary item-code lists for divisions 01, 02, 03, 05, 06 and 10 are **identical in all 14 releases**. Changes in the other divisions:

| Division | 2011–2012 | Change |
|---|---|---|
| `p601t` Food | 67 item codes | none |
| `p602t` Alcohol & tobacco | 10 item codes | none. The narcotics code `c23111` is in the formula but not released (≤0.07% of households affected). |
| `p603t` Clothing | 21 item codes | none |
| `p604t` Housing | `b010 b020 b050 b053p b056p b060 b102 b104 b107 b108 b159 b017 b018 + (b170−b173) + (b175−b178) + b223 + b224` + item codes | **2013:** combined gas+electricity bills added (`+b231 +b232 +b233 −b174`) plus separate meter payments (`+b1701 +b1751`). Diary slot-meter codes `c45114`/`c45214` are dropped (only the child parts `c45114c`/`c45214c` remain). **2015-16:** `b223`, `b224` and `b232` (standing orders) are no longer in the data and drop out. |
| `p605t` Furnishings | `b270 b271` + item codes | none |
| `p606t` Health | 17 item codes | none |
| `p607t` Transport | `b216 b217 b218 b219 b244 b245 b247 b248 b249 b250 b252` + item codes | **2013:** air fares come from the questionnaire (`+b487` domestic, `+b488` international flights). Diary air fares `c73311`/`c73312` are dropped except the children's parts (`c73311c`, `c73312c`). |
| `p608t` Communication | `b166 b1661 b195` + item codes | **2013:** `c94245` moves to recreation. **2018-19:** `b166`/`b1661`/`b195` are replaced by the single-bill variables **`b166b`** (telephone), **`b1661b`** (mobile) and **`b195b`** (internet), plus **`b167`, the combined TV/telecoms/internet bill**. None of these are documented. |
| `p609t` Recreation | `b162 b181 b191 b192 b193 b2441 b2451 b480 b481` + item codes | **2013:** `+c94245t`. **2018-19:** TV variables `b191`–`b193` are replaced by **`b190`** (online video/film subscriptions) and **`b194b`** (TV account, single bill). Neither is documented. |
| `p610t` Education | `b160 b164` + item codes | none |
| `p611t` Restaurants & hotels | `b482 b483 b484 b485` + **`b260t`** + item codes | **All years:** school meals enter as **`b260t`**, not the documented `b260` + `b260c` (they differ for about 3% of households). **2013:** children's holiday accommodation codes `cb2111c`/`cb2112c` drop out. Room hire enters as the adult code `cb2114` only. |
| `p612t` Misc goods & services | `b110 b168 b1802 b188 b229 b238 b273 b280 b281 b282 b283` + item codes | **2018-19:** **`+b189`** (non-package travel insurance), **`+b199`** (household appliance insurance) and **`+max(b2291 − p087, 0)`**. `b2291` is accident, sickness and pet insurance; the part up to `p087` ("other insurance incl. deductions from wages") goes to non-consumption. None of this is documented. |

### 5.2 Complete list for 2024-25

This is the latest release. Item-code lists for earlier years differ only as shown in §5.1; use the CSV for exact per-year lists.

<!-- generated from data/consumption_components.csv -->

#### `p601t` — 01 Food & non-alcoholic drinks

Diary / COICOP-plus item codes (67), all added: `c11111t`, `c11121t`, `c11122t`, `c11131t`, `c11141t`, `c11142t`, `c11151t`, `c11211t`, `c11221t`, `c11231t`, `c11241t`, `c11251t`, `c11252t`, `c11253t`, `c11261t`, `c11271t`, `c11311t`, `c11321t`, `c11331t`, `c11341t`, `c11411t`, `c11421t`, `c11431t`, `c11441t`, `c11451t`, `c11461t`, `c11471t`, `c11511t`, `c11521t`, `c11522t`, `c11531t`, `c11541t`, `c11551t`, `c11611t`, `c11621t`, `c11631t`, `c11641t`, `c11651t`, `c11661t`, `c11671t`, `c11681t`, `c11691t`, `c11711t`, `c11721t`, `c11731t`, `c11741t`, `c11751t`, `c11761t`, `c11771t`, `c11781t`, `c11811t`, `c11821t`, `c11831t`, `c11841t`, `c11851t`, `c11861t`, `c11911t`, `c11921t`, `c11931t`, `c11941t`, `c12111t`, `c12121t`, `c12131t`, `c12211t`, `c12221t`, `c12231t`, `c12241t`

#### `p602t` — 02 Alcohol, tobacco & narcotics

Diary / COICOP-plus item codes (10), all added: `c21111t`, `c21211t`, `c21212t`, `c21213t`, `c21214t`, `c21221t`, `c21311t`, `c22111t`, `c22121t`, `c22131t`

#### `p603t` — 03 Clothing & footwear

Diary / COICOP-plus item codes (21), all added: `c31111t`, `c31211t`, `c31212t`, `c31221t`, `c31222t`, `c31231t`, `c31232t`, `c31233t`, `c31234t`, `c31311t`, `c31312t`, `c31313t`, `c31314t`, `c31315t`, `c31411t`, `c31412t`, `c31413t`, `c32111t`, `c32121t`, `c32131t`, `c32211t`

#### `p604t` — 04 Housing, water, electricity, gas

Questionnaire / derived terms:

| sign | variable | label |
|---|---|---|
| + | `b010` | Rent rates - last net payment |
| + | `b020` | Net rent - service charge deducted |
| + | `b102` | Central heating repairs - second dwelling |
| + | `b104` | Central heating repairs - main dwelling |
| + | `b107` | House maintenance etc. - main dwelling |
| + | `b108` | House maintenance etc. - second dwelling |
| + | `b050` | Water charges - last net payment |
| + | `b060` | Other regular housing payments |
| + | `b159` | Service charge included in rent - amount |
| + | `b175` | Electricity amount paid in last account |
| − | `b178` | Rebate for separate Electricity amount |
| + | `b170` | Gas amount paid in last account |
| − | `b173` | Rebate for separate Gas amount |
| + | `b018` | Bottled gas for central heating |
| + | `b017` | Oil for central heating - last quarter |
| + | `b053p` | Council water tax - weekly amount paid |
| + | `b056p` | Council sewerage tax - weekly amount paid |
| + | `b1751` | Separate electricity meter payment |
| + | `b1701` | Separate gas meter payment |
| + | `b231` | Combined gas and electricity bill - account |
| + | `b233` | Combined gas and electricity - pre-payment meter |
| − | `b174` | Rebate for combined gas and electricity |

Diary / COICOP-plus item codes (14), all added: `c41211t`, `c43111t`, `c43112t`, `c44211t`, `c45112t`, `c45212t`, `c45222t`, `c45312t`, `c45411t`, `c45412t`, `c45511t`, `c43212c`, `c45114c`, `c45214c`

#### `p605t` — 05 Furnishings & household equipment

Questionnaire / derived terms:

| sign | variable | label |
|---|---|---|
| + | `b270` | Furniture |
| + | `b271` | Soft floor covering |

Diary / COICOP-plus item codes (45), all added: `c51212t`, `c51113t`, `c51114t`, `c51311t`, `c52111t`, `c52112t`, `c53111t`, `c53121t`, `c53122t`, `c53131t`, `c53132t`, `c53133t`, `c53141t`, `c53151t`, `c53161t`, `c53171t`, `c53211t`, `c53311t`, `c53312t`, `c53313t`, `c53314t`, `c54111t`, `c54121t`, `c54131t`, `c54132t`, `c54141t`, `c55111t`, `c55112t`, `c55211t`, `c55212t`, `c55213t`, `c55214t`, `c56111t`, `c56112t`, `c56121t`, `c56122t`, `c56123t`, `c56124t`, `c56125t`, `c56211t`, `c56221t`, `c56222t`, `c56223t`, `c51111c`, `c51211c`

#### `p606t` — 06 Health

Diary / COICOP-plus item codes (17), all added: `c61111t`, `c61112t`, `c61211t`, `c61311t`, `c61312t`, `c61313t`, `c62111t`, `c62112t`, `c62113t`, `c62114t`, `c62211t`, `c62212t`, `c62311t`, `c62321t`, `c62322t`, `c62331t`, `c63111t`

#### `p607t` — 07 Transport

Questionnaire / derived terms:

| sign | variable | label |
|---|---|---|
| + | `b244` | Vehicle - cost of new car/van outright |
| + | `b245` | Vehicle - cost of second-hand car/van outright |
| + | `b247` | Vehicle - cost of motorcycle outright |
| + | `b249` | Car or van - servicing : amount paid |
| + | `b250` | Car or van - other works, repairs: amount paid |
| + | `b252` | Motor cycle - services, repairs: amount paid |
| + | `b248` | Car leasing on |
| + | `b218` | Season ticket-rail/tube-total net amount |
| + | `b217` | Season ticket-bus/coach-total net amount |
| + | `b219` | Water travel season ticket |
| + | `b216` | Bus Tube and/or rail season ticket |
| + | `b488` | International flight expenditure |
| + | `b487` | Domestic flight expenditure |

Diary / COICOP-plus item codes (34), all added: `c71112t`, `c71122t`, `c71212t`, `c71311t`, `c71411t`, `c72111t`, `c72112t`, `c72113t`, `c72114t`, `c72115t`, `c72211t`, `c72212t`, `c72213t`, `c72313t`, `c72314t`, `c72411t`, `c72412t`, `c72413t`, `c72414t`, `c73112t`, `c73212t`, `c73213t`, `c73214t`, `c73411t`, `c73512t`, `c73513t`, `c73611t`, `c71111c`, `c71121c`, `c71211c`, `c72311c`, `c72312c`, `c73311c`, `c73312c`

#### `p608t` — 08 Communication

Questionnaire / derived terms:

| sign | variable | label |
|---|---|---|
| + | `b167` | Combined TV, Telecoms and Internet bill, |
| + | `b1661b` | Mobile account – single bill |
| + | `b195b` | Internet weekly – single bill |
| + | `b166b` | Telephone account – single bill |

Diary / COICOP-plus item codes (9), all added: `c81111t`, `c82111t`, `c82112t`, `c82113t`, `c83112t`, `c83114t`, `c83115t`, `c83111c`, `c83113c`

#### `p609t` — 09 Recreation & culture

Questionnaire / derived terms:

| sign | variable | label |
|---|---|---|
| + | `b162` | Leisure class fees paid - amount |
| + | `b181` | TV licence - amount paid last year |
| + | `b480` | Holiday package within United Kingdom |
| + | `b481` | Holiday package outside United Kingdom |
| + | `b2441` | Vehicle - cost of new motor caravan outright |
| + | `b2451` | Vehicle - cost of second-hand motor caravan out |
| + | `b190` | Online Video Film packages, DVD rental |
| + | `b194b` | TV account – single bill |

Diary / COICOP-plus item codes (77), all added: `c91111t`, `c91112t`, `c91113t`, `c91121t`, `c91122t`, `c91123t`, `c91124t`, `c91125t`, `c91126t`, `c91127t`, `c91128t`, `c91211t`, `c91221t`, `c91311t`, `c91411t`, `c91412t`, `c91413t`, `c91414t`, `c91511t`, `c92111t`, `c92112t`, `c92117t`, `c92211t`, `c92221t`, `c92311t`, `c93111t`, `c93112t`, `c93113t`, `c93114t`, `c93211t`, `c93212t`, `c93311t`, `c93312t`, `c93313t`, `c93411t`, `c93412t`, `c93511t`, `c94111t`, `c94112t`, `c94113t`, `c94115t`, `c94211t`, `c94212t`, `c94221t`, `c94232t`, `c94236t`, `c94238t`, `c94239t`, `c94241t`, `c94242t`, `c94243t`, `c94244t`, `c94245t`, `c94246t`, `c94311t`, `c94312t`, `c94313t`, `c94314t`, `c94315t`, `c94316t`, `c94319t`, `c95111t`, `c95211t`, `c95212t`, `c95311t`, `c95411t`, `c92114t`, `c92116t`, `c94114c`, `c94231c`, `c94233c`, `c94235c`, `c94237c`, `c96111c`, `c96112c`, `c92113c`, `c92115c`

#### `p610t` — 10 Education

Questionnaire / derived terms:

| sign | variable | label |
|---|---|---|
| + | `b160` | Education – total amount paid last quarter |
| + | `b164` | Members outside household – total education fees for last quarter |

Diary / COICOP-plus item codes (15), all added: `ca1113t`, `ca2113t`, `ca3113t`, `ca4113t`, `ca5113t`, `ca1111c`, `ca1112c`, `ca2111c`, `ca2112c`, `ca3111c`, `ca3112c`, `ca4111c`, `ca4112c`, `ca5111c`, `ca5112c`

#### `p611t` — 11 Restaurants & hotels

Questionnaire / derived terms:

| sign | variable | label |
|---|---|---|
| + | `b482` | Holiday hotel within United Kingdom |
| + | `b483` | Holiday hotel outside United Kingdom |
| + | `b484` | Holiday self-cathering within United Kingdom |
| + | `b485` | Holiday self-cathering outside United Kingdom |
| + | `b260t` | School meals - total amount paid last week |

Diary / COICOP-plus item codes (30), all added: `cb1111t`, `cb1112t`, `cb1113t`, `cb1114t`, `cb1115t`, `cb1116t`, `cb111ct`, `cb111dt`, `cb111et`, `cb111ft`, `cb111gt`, `cb111ht`, `cb111it`, `cb111jt`, `cb1121t`, `cb1122t`, `cb1123t`, `cb1124t`, `cb1125t`, `cb1126t`, `cb1127t`, `cb1128t`, `cb112bt`, `cb1213t`, `cb1117c`, `cb1118c`, `cb1119c`, `cb111ac`, `cb111bc`, `cb2114`

#### `p612t` — 12 Misc goods & services

Questionnaire / derived terms:

| sign | variable | label |
|---|---|---|
| + | `b110` | Structure insurance - last payment |
| + | `b168` | Content insurance amount of last premium |
| + | `b188` | Vehicle insurance - amount paid last year |
| + | `b1802` | Bank and Building societies charges - net amount last 3 months |
| + | `b229` | Medical insurance - total amount premium |
| + | `b238` | Annual standing charge for credit cards |
| + | `b273` | Furniture removal and or storage |
| + | `b280` | Property transaction - purchase and sale |
| + | `b281` | Property transaction - sale only |
| + | `b282` | Property transaction - purchase only |
| + | `b283` | Property transaction - other payments |
| + | `b189` | Travel insurance (non-package holiday) |
| + | `b199` | Insurance for household and electrical appliances |
| + | `max(b2291-p087,0)` | b2291 = accident, sickness & animal insurance; p087 = other insurance incl. deductions from wages |

Diary / COICOP-plus item codes (34), all added: `cc1111t`, `cc1211t`, `cc1311t`, `cc1312t`, `cc1313t`, `cc1314t`, `cc1315t`, `cc1316t`, `cc1317t`, `cc3111t`, `cc3112t`, `cc3211t`, `cc3221t`, `cc3222t`, `cc3223t`, `cc3224t`, `cc4111t`, `cc4112t`, `cc4121t`, `cc4122t`, `cc5213t`, `cc5411c`, `cc5412t`, `cc5413t`, `cc6212t`, `cc6214t`, `cc7111t`, `cc7112t`, `cc7113t`, `cc7114t`, `cc7115t`, `cc7116t`, `cc5311c`, `cc6211c`

#### `p620tp` — Non-consumption expenditure

Questionnaire / derived terms:

| sign | variable | label |
|---|---|---|
| + | `b150p` | Mortgage interest / principle - interest paid - anonymised |
| + | `b2081` | Mortgage protection amount premium |
| + | `b038p` | Council tax - last payment weekly amount |
| + | `b030` | Domestic rates - last net payment |
| + | `b187` | Vehicle road tax - amount paid last year |
| − | `b179` | Vehicle road tax - amount refunded last |
| + | `b334h` | Money sent abroad - household |
| + | `b265` | Maintenance allowance expenditure |
| + | `b237` | Credit card interest payments |
| + | `b228` | Personal pension |
| + | `b1961` | Life insurance premium - amount premium |
| + | `b2011` | Mortgage endowment policy amount premium |
| + | `b205` | Friendly socs - deductions from main pay |
| + | `b206` | Other insurance - total amount premium |
| + | `min(b2291,p087)` | b2291 = accident, sickness & animal insurance; p087 = other insurance incl. deductions from wages |

Diary / COICOP-plus item codes (24), all added: `ck1315t`, `ck1316t`, `ck2111t`, `ck3111t`, `ck3112t`, `ck4111t`, `ck4112t`, `ck5221t`, `ck5222t`, `ck5223t`, `ck5212t`, `ck5213t`, `ck5214t`, `ck5215t`, `ck5216t`, `ck5111t`, `ck5113t`, `ck1313t`, `ck1314t`, `ck5224c`, `ck5315c`, `cc5111c`, `cc5312c`, `cc5511c`


## 6. Verification: rebuilt versus published totals (England)

**Share of households where the rebuilt total equals the published one** (tolerance £0.01; £0.30 in 2024-25, where values are rounded to £0.10):

| | 2011 | 2012 | 2013 | 2014 | 15-16 | 16-17 | 17-18 | 18-19 | 19-20 | 20-21 | 21-22 | 22-23 | 23-24 | 24-25 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `p601t` `p603t` `p605t` `p606t` `p607t` `p608t` `p610t` `p611t` | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 |
| `p602t` | 100 | 99.96 | 99.98 | 99.93 | 100 | 99.98 | 99.98 | 99.93 | 99.95 | 100 | 100 | 100 | 100 | 100 |
| `p604t` | 99.96 | 99.96 | 99.98 | 96.65 | 96.50 | 95.75 | 95.61 | 99.73 | 99.95 | 99.93 | 99.93 | 99.94 | 100 | 99.97 |
| `p609t` | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 99.93 | 99.36 | 98.37 | 98.59 | 98.08 | 97.97 | 99.09 |
| `p612t` | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 98.00 | 98.14 | 98.71 | 98.87 | 98.75 | 98.66 | 98.46 |
| **`p600t`** | 99.96 | 99.91 | 99.95 | 96.90 | 96.79 | 96.20 | 96.05 | 97.61 | 97.42 | 97.08 | 97.44 | 96.81 | 96.73 | 96.82 |
| `p620tp` (non-consumption) | 99.87 | 99.94 | 99.93 | 98.66 | 99.90 | 98.62 | 99.01 | 97.46 | 97.17 | 97.97 | 98.24 | 97.93 | 97.76 | 94.76 |

**Size of the gaps:** the weighted mean absolute difference for `p600t` is £0.005–£0.20 per week. Mean `p600t` in England is £420 (2011) to £598 (2024-25), so the gap is under 0.05% of consumption. The full table, including weighted means of each division, is in `data/verification_england.csv`.

What is still unexplained, all small:
- **`p604t`, 2014 to 2017-18** (about 4% of households, mean absolute gap ≤ £0.07): concentrated in households with combined gas+electricity bills (`b231`). Replacing `b231` with its gas and electricity components (`b226 + b227`) helps a little but not fully. ONS seems to apply a split or rebate step that cannot be seen in the public data.
- **`p609t`, 2018-19 onward** (1–2% of households, ≤ £0.07): for some households `b194b` (TV single bill) is not counted, and no released variable predicts which.
- **`p612t`, 2018-19 onward** (about 1.5% of households, ≤ £0.12): left over from the `b2291`/`p087` insurance allocation. `p087` is built from person-level insurance records that are only partly released.
- **`p602t`:** narcotics (`c23111`) are not released.
- **Scotland only (irrelevant for England):** housing uses the unanonymised water and sewerage charges, so Scottish `p604t` cannot be reproduced exactly.
- **`p620tp`:** the second-home items (`p129t` versus its item codes) affect under 1% of households and the treatment cannot be pinned down. **2024-25:** households with a mortgage often have `b150p = 0` (mortgage interest suppressed in the public file) while `p620tp` still includes it. This affects non-consumption and total expenditure, not consumption.

## 7. Where the official documentation is wrong or out of date

1. **Volume F's household-total (`t`) formulas were last updated in 2013.** The adult formulas were updated for the 2013 gas/electricity redesign and flight questions; the `t` versions were not (they still list `b221`/`b222`, which do not exist). Build the household totals from the adult formula's `b` codes plus the `t` versions of its item codes, as in §3.
2. **The 2018-19 telecoms redesign is missing from Volume F and Volume I**, including the 2024-25 editions. The published totals use `b166b`, `b1661b`, `b195b` and `b167` (communication) and `b190`, `b194b` (recreation).
3. **School meals:** the published `p611t` uses `b260t`, not `b260` + `b260c`.
4. **Insurance from 2018-19:** `b189`, `b199` and part of `b2291` are in `p612t` but not documented.
5. Several documented variables are **not in the public release:** `c23111` (narcotics), `cc2111`, `c51112`, `c94234c`, `c44112u`, and unanonymised `…u` variables.
6. Volume I (2023-24 and 2024-25) also uses unanonymised amounts (`b038u`, `b053u`, `b056u`, `p220urnt`), so its sub-category formulas cannot be applied exactly to public data.

## 8. Comparability over time (consumption)

Weighted mean `p600t`, England, £ per week, nominal:

| 2011 | 2012 | 2013 | 2014 | 15-16 | 16-17 | 17-18 | 18-19 | 19-20 | 20-21 | 21-22 | 22-23 | 23-24 | 24-25 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 420.0 | 430.6 | 447.6 | 467.3 | 464.1 | 490.4 | 512.6 | 523.7 | 520.1 | 424.4 | 462.3 | 498.8 | 548.3 | 597.6 |

Breaks to handle:
- **2018-19, communication:** the whole combined TV/telecoms/internet bill (`b167`) now goes to `p608t`, including the TV part that used to be in `p609t`. Communication jumps from £17.9 to £21.4. The total is unaffected.
- **2018-19, other questionnaire redesign:** energy bill splits, insurance, and the person-level housing benefit questions (which affect net rent). The released 2018-19 data are the corrected 4th edition: transport spending was understated by about 6% in the original release.
- **2013:** the gas/electricity questions and the move of flights to the questionnaire. Divisions 04 and 07 are defined differently before and after.
- **2020-21 (COVID):** telephone interviewing and few interviews in April 2020 (also March 2020 in 2019-20). Restaurants, recreation, transport and clothing collapse.
- **Calendar to financial year in 2015-16.** Use the Jan–Mar 2015 file, or `year` and `a055`, if you need calendar years.
- **2024-25:** values are stored rounded to £0.10, the weights are renamed, and only the v3 file has weights.
- The England sample falls from about 4,800 (2011) to about 2,900 (2023-24).

## 9. Reproducing this

The scripts in `scripts/` take the unzipped UKDS folders as input (`<root>/<SN>/UKDA-<SN>-stata/...`) and need pandas. They were run with `GOLD/.venv`.

1. `formulas.py <root> formulas.json`: parses Volume F Part 3 for every release.
2. `build_t.py <root> formulas.json <scripts> built.json`: builds the household-total formulas and searches the gaps for missing variables.
3. `final_formulas.py <root> built.json <scripts> final.json`: applies the fixes in §5.1 and verifies on England (writes `final_verification.csv`).
4. `export.py <root> final.json <scripts> formulas.json components.csv`: writes the per-release variable list.

### Building the pooled dataset (Stata)

`scripts/build_lcf_consumption.do` reads the 14 UKDS zips (unzipping them if needed) and writes one row per household per survey year, England only, with annual consumption `cons_annual` = (`p600t` + `b230`) × 52 (nominal £) and the 12 divisions `c_*`. By default it adds housing benefit and rent rebates (`b230`) back onto rent, because ONS takes them out of rent so benefit-funded rent is not counted as consumption; this also removes the few negative totals. Set `add_back_hb = 0` to get the published totals, which are also kept as `cons_annual_pub`. It prints its assumptions [A0]–[A11] when it runs, and they are tagged `>>> ASSUMPTION` in the code. Set `$LCF_ZIPS`, `$LCF_WORK` and `$LCF_OUT` before running it to change the paths. By default the output is saved next to the raw data, not in this repo, because of the UKDS licence.
