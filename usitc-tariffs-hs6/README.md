# US effective tariff rates, HS6 × country, 2025–2026

Monthly US imports for consumption by **HS6 subheading and partner country**,
with calculated duties and the **effective tariff rate** (duties ÷ customs
value), January 2025 through **August 2026**, from USITC DataWeb. Pulled
2026-10-19.

```
usitc-tariffs-hs6/
├── data/effective_tariffs_hs6.csv.gz   the panel
├── data/hs6_descriptions.csv           HS6 code → DataWeb description
├── scripts/fetch_effective_tariffs.py  rebuilds both files
└── raw/                                DataWeb responses (gitignored)
```

## data/effective_tariffs_hs6.csv.gz

1,729,488 rows, one per year × month × HS6 × country with any trade or duty;
5,528 HS6 subheadings, 232 countries. Current US dollars.

| Column | Meaning |
|---|---|
| `year`, `month` | reference period |
| `hs6` | 6-digit HTS subheading, kept as text (`010121`) |
| `country` | DataWeb country name (DataWeb gives names, not codes) |
| `customs_value_usd` | imports for consumption, customs value (`CONS_CUSTOMS_VALUE`) |
| `calc_duty_usd` | calculated duties (`CONS_CALC_DUTY`) |
| `effective_rate` | `calc_duty_usd / customs_value_usd`, 6 decimals |

Rows are grouped by year and chapter, not sorted globally.

### Things to know

- **The rate includes everything that was charged.** Calculated duties cover
  MFN duty plus the Chapter 99 add-ons (Section 232, Section 301, IEEPA
  reciprocal and fentanyl duties) as assessed on the entry. The rate falls
  where goods enter under FTAs, exclusions or duty-free programs, which is the
  point of an effective rate. It is not the statutory rate.
- **Imports for consumption, not general imports.** Duty is assessed when goods
  enter US commerce, including withdrawals from bonded warehouses and FTZs.
  Value and duty are on the same basis. Census general-imports figures (as in
  `state-imports-hs6/`) will not match exactly.
- **Duties are as charged at entry, not net of refunds.** IEEPA duties were
  struck down in February 2026 and refunded in large amounts from May 2026
  (Treasury net customs receipts were negative in May–July 2026). The 2025
  IEEPA months here show duties that were later partly refunded.
- **Below Treasury receipts by 6–14%.** Calculated duty runs under Treasury
  gross customs collections for the following month, the usual payment lag,
  but moves with it month for month.
- **The denominator is all customs value**, duty-free entries included. The
  DataWeb API offers no dutiable-value field.
- **Rates above 100% are real.** 1,085 rows, mostly small shipments; the
  largest are Chinese electric vehicles (870380) at 115–147%.
- **All-zero rows are dropped.** DataWeb lists every HS6 × country pair traded
  at any point in the year; months with no trade and no duty are left out.
- **Totals reconcile.** Summed over HS6 and country, every month matches
  DataWeb's all-commodity, all-country total for both value and duty (checked
  2026-10-19 for all 20 months).
- **Data gets revised.** Census, DataWeb's source, revises recent months and
  publishes annual revisions in June. Rerun with `--refresh` to pick them up.

Overall rate by month, for orientation:

| | Jan | Apr | Jul | Oct | | Jan | Mar | Jun | Aug |
|---|---|---|---|---|---|---|---|---|---|
| 2025 | 2.2% | 7.2% | 9.5% | 10.8% | **2026** | 9.9% | 6.9% | 6.8% | 6.9% |

## Rebuilding

```
python scripts/fetch_effective_tariffs.py            # resume
python scripts/fetch_effective_tariffs.py --refresh  # refetch everything
```

Needs a DataWeb API token (free: sign in at dataweb.usitc.gov with Login.gov,
then the API tab), read from `DATAWEB_API_KEY` or `dataweb_api_key` in the
repo-root `.env`.

DataWeb declines requests whose result is too large, so a chapter is split into
HS4 headings, and a heading into HS6 subheadings, when needed (39, 61, 62, 84,
85, 90 and others are split). That makes about 640 requests. DataWeb returns 429
to a sustained burst, so the script sends one request at a time with a pause; a
full refetch takes about an hour. Responses are saved in `raw/` and reused.
