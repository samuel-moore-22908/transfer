# transfer

Staging repo for data and outputs on their way somewhere else.

One directory per task, each self-contained: its own `data/`, `scripts/`,
`raw/` and `README.md`, so a directory can be copied out on its own and still
make sense. Nothing loose at the root.

| Task | What it holds |
|---|---|
| [`france-cantons/`](france-cantons/) | Canton boundary shapefiles for France (métropole + DOM), from IGN ADMIN EXPRESS, with INSEE canton names joined on |
| [`usitc-tariffs-hs6/`](usitc-tariffs-hs6/) | Monthly US imports for consumption, calculated duties and effective tariff rate by HS6 × partner country, Jan 2025 – Aug 2026, from USITC DataWeb |
