"""Build data/uk_us_hs4_2026.csv — monthly HS4 goods trade between the UK and
the United States as a whole, January 2026 to the latest released month.

Same columns as data/uk_midwest_hs4_2026.csv (built by fetch_trade.py), with
state = "US", so the two files stack. Source is the Census Bureau International
Trade API, national HS endpoints:
    timeseries/intltrade/exports/hs
    timeseries/intltrade/imports/hs

    python scripts/fetch_trade_us.py

Needs a Census API key, read from CENSUS_API_KEY or from census_api_key in the
repo-root .env. Raw API responses are saved into raw/ on every run.
"""
import csv
import json
import os
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(HERE)
RAW = os.path.join(HERE, "raw")
OUT = os.path.join(HERE, "data", "uk_us_hs4_2026.csv")

BASE = "https://api.census.gov/data/timeseries/intltrade/{flow}/hs"
UK = "4120"          # Census Schedule C code for the United Kingdom
START = "2026-01"

# Per flow: commodity code, description, and the value columns to keep.
FLOWS = {
    "exports": {
        "code": "E_COMMODITY",
        "desc": "E_COMMODITY_LDESC",
        "vals": {"value_usd": "ALL_VAL_MO", "air_val_usd": "AIR_VAL_MO",
                 "ves_val_usd": "VES_VAL_MO", "cnt_val_usd": "CNT_VAL_MO"},
    },
    "imports": {
        "code": "I_COMMODITY",
        "desc": "I_COMMODITY_LDESC",
        # general imports; imports for consumption kept alongside
        "vals": {"value_usd": "GEN_VAL_MO", "con_val_usd": "CON_VAL_MO",
                 "air_val_usd": "AIR_VAL_MO", "ves_val_usd": "VES_VAL_MO",
                 "cnt_val_usd": "CNT_VAL_MO"},
    },
}
COLUMNS = ["flow", "state", "year", "month", "hs4", "hs4_desc",
           "value_usd", "con_val_usd", "air_val_usd", "ves_val_usd", "cnt_val_usd"]


def api_key():
    key = os.environ.get("CENSUS_API_KEY")
    if key:
        return key
    with open(os.path.join(ROOT, ".env"), encoding="utf-8") as fh:
        for line in fh:
            name, _, value = line.strip().partition("=")
            if name.strip().lower() == "census_api_key":
                return value.strip().strip("'\"")
    raise SystemExit("no Census API key: set CENSUS_API_KEY or census_api_key in .env")


def fetch(flow, key):
    spec = FLOWS[flow]
    fields = [spec["code"], spec["desc"], *spec["vals"].values()]
    query = urllib.parse.urlencode({
        "get": ",".join(fields),
        "COMM_LVL": "HS4",
        "CTY_CODE": UK,
        "time": "from " + START,
        "key": key,
    })
    with urllib.request.urlopen(BASE.format(flow=flow) + "?" + query) as resp:
        body = resp.read().decode("utf-8")
    if not body.strip():        # the API answers 204/empty when nothing matches
        return []
    with open(os.path.join(RAW, f"{flow}_US.json"), "w", encoding="utf-8") as fh:
        fh.write(body)
    header, *rows = json.loads(body)
    return [dict(zip(header, r)) for r in rows]


def main():
    key = api_key()
    os.makedirs(RAW, exist_ok=True)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)

    out = []
    for flow, spec in FLOWS.items():
        rows = fetch(flow, key)
        print(f"{flow} US: {len(rows)} rows")
        for r in rows:
            year, month = r["time"].split("-")
            rec = {"flow": flow[:-1], "state": "US", "year": int(year),
                   "month": int(month), "hs4": r[spec["code"]],
                   "hs4_desc": r[spec["desc"]].strip()}
            for col, var in spec["vals"].items():
                rec[col] = int(r[var])
            out.append(rec)

    out.sort(key=lambda r: (r["flow"], r["year"], r["month"], r["hs4"]))
    with open(OUT, "w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=COLUMNS)
        w.writeheader()
        w.writerows(out)
    print(f"wrote {len(out)} rows to {OUT}")


if __name__ == "__main__":
    main()
