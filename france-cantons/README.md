# french cantons — shapefiles

Canton boundaries for France (métropole + DOM). Cantons are the electoral
subdivisions of the *départements*, as redrawn by the 2015 *redécoupage*.

```
france-cantons/
├── data/
│   ├── canton/                       IGN original, untouched
│   ├── canton_named/                 same geometry + names   <- default choice
│   └── canton_2025_dom_rapproches/   newer, but DOM displaced
├── scripts/                          rebuild the two derived layers
└── raw/                              downloaded sources (gitignored)
```

| Layer | Polygons | Coordinates | Use it for |
|---|---|---|---|
| `data/canton/CANTON.shp` | 2044 | WGS84, true positions | the untouched IGN original |
| `data/canton_named/CANTON_NAMED.shp` | 2044 | WGS84, true positions | **default choice** — canton names and a national key |
| `data/canton_2025_dom_rapproches/CANTON_2025_DOM_RAPPROCHES.shp` | 2061 | WGS84, **DOM displaced** | national maps only (see warning) |

Every layer carries the full sidecar set (`.shp`, `.shx`, `.dbf`, `.prj`, `.cpg`);
the `.shp` alone will not open. DBF text is UTF-8, declared in the `.cpg`.

## data/canton — IGN original

IGN **ADMIN EXPRESS COG CARTO 3.2**, edition 2024-02-22, WGS84 geographic
(EPSG:4326), cartographic generalisation. Extracted verbatim from the official
archive; licence Etalab 2.0 (open, attribution to IGN).

Fields: `ID`, `INSEE_CAN`, `INSEE_DEP`, `INSEE_REG`.

Note `INSEE_CAN` is only the two-character code *within* the department, so it
is not unique nationally — join on `INSEE_DEP + INSEE_CAN`.

## data/canton_named — IGN geometry + INSEE names

Identical geometry, with the DBF enriched from the INSEE COG 2024 canton table:

| Field | Meaning |
|---|---|
| `ID` | IGN feature id |
| `CAN_CODE` | `INSEE_DEP + INSEE_CAN` — unique national key (`0101`, `97101`) |
| `INSEE_CAN`, `INSEE_DEP`, `INSEE_REG` | INSEE canton / department / region codes |
| `NOM` | canton name, INSEE `LIBELLE` (`Ambérieu-en-Bugey`) |
| `NOM_MAJ` | INSEE `NCC`, uppercase and unaccented (`AMBERIEU EN BUGEY`) |
| `BURCENTRAL` | commune code of the *bureau centralisateur* |

### How the 2044 polygons break down

IGN builds canton geometry by aggregating whole communes, so the polygon count
is not the canton count:

- **1803** ordinary cantons, one polygon each;
- **217** city polygons with `INSEE_CAN` 97/98/99. Where one commune is split
  across several cantons (Gap-1…Gap-4, Marseille, Nice…), IGN draws the commune
  once instead of the cantons. 251 INSEE cantons collapse into these;
- **20** pseudo-cantons covering *communes nouvelles* that straddle cantons;
- **4** placeholders with `INSEE_CAN = 'NR'` and no name — Paris, Métropole de
  Lyon, Martinique and Guyane have no cantons at all.

So a canton-level dataset keyed on the 2054 INSEE cantons will not join
one-to-one; aggregate your data to `CAN_CODE` first.

## data/canton_2025_dom_rapproches — newer, but displaced

Built from IGN Admin Express COG PLUS 2025 as published on data.gouv.fr
(fields `CODGEO`, `LIBGEO`, `DEPT`, `REG`, `COMPOSITIO`). More recent, and it
keeps the split-commune cantons separate — but **the overseas departments have
been moved next to metropolitan France** so the country fits one frame:
Guadeloupe sits at ~4°W/46°N, Réunion at ~3°W/42°N, Mayotte at ~0°E/41°N.

Fine for a national choropleth. Never use it for coordinates, distances, or
spatial joins against anything else.

## Rebuilding

```
pip install pyshp
python scripts/build_canton_named.py
python scripts/build_canton_2025_dom_rapproches.py
```

Both scripts download what they need into `raw/`. The IGN geometry in
`data/canton/` is not scripted — it is the `CANTON.*` layer lifted straight out
of the official archive:

```
curl -O https://data.geopf.fr/telechargement/download/ADMIN-EXPRESS-COG-CARTO/\
ADMIN-EXPRESS-COG-CARTO_3-2__SHP_WGS84G_FRA_2024-02-22/\
ADMIN-EXPRESS-COG-CARTO_3-2__SHP_WGS84G_FRA_2024-02-22.7z          # 163 MB
7z e ADMIN-EXPRESS-COG-CARTO_3-2__SHP_WGS84G_FRA_2024-02-22.7z -odata/canton -r "CANTON.*"
```

## Sources

- IGN ADMIN EXPRESS COG CARTO — https://geoservices.ign.fr/adminexpress
- INSEE COG 2024 cantons — https://www.insee.fr/fr/information/7766585
- Admin Express COG PLUS 2025 (data.gouv.fr) — https://www.data.gouv.fr/datasets/communes-cantons-et-epci-2025-admin-express-cog-plus-ign
