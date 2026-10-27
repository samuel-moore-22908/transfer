# Germany regional price index, 2022

Regional price levels for Germany's 400 Kreise (districts and district-free
cities), 2022. Added 2026-10-27 from a file supplied directly; no fetch script.

```
germany-regional-prices/
└── data/regional_price_index_2022.csv   one row per Kreis, UTF-8
```

| Column | Meaning |
|---|---|
| `ags` | Kreis code (Amtlicher Gemeindeschlüssel, 5 digits, kept as text: leading zeros matter) |
| `kreis` | Kreis name |
| `state` | Bundesland |
| `rpi_total_2022` | price level, all goods and services |
| `rpi_excl_housing_2022` | price level excluding housing |
| `rpi_housing_2022` | price level of housing |

The indices appear to be scaled so that Germany = 100. Unweighted means across
Kreise are 98.2 (total), 99.9 (excl. housing) and 94.1 (housing), consistent
with a population-weighted base. Most of the spread is housing: it runs from
68.0 (Vogtlandkreis) to 180.9 (München), while prices excluding housing stay
within 98.3–104.2.

Source: not recorded. Add the publisher and release here before citing.
