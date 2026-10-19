"""Build data/state_imports_hs6.csv.gz — monthly imports by state of destination,
partner country and HS6 subheading, January 2025 to the latest released month,
for every state code the API reports (50 states, DC, PR, VI and the
unallocated XX).

Source is the Census Bureau International Trade API:
    timeseries/intltrade/imports/statehs   state × country × HS6 values
    timeseries/intltrade/imports/hs        HS6 descriptions, country names,
                                           and the list of released months

    python scripts/fetch_state_imports_hs6.py            # resume
    python scripts/fetch_state_imports_hs6.py --refresh  # refetch everything

One request per state and month (about 1,100). They take 5-75 s each, so the
script runs WORKERS of them at once and saves each response, gzipped, into
raw/. A rerun skips state-months already in raw/, so an interrupted pull picks
up where it stopped. Use --refresh after a new Census release to pick up
revisions.

Needs a Census API key, read from CENSUS_API_KEY or from census_api_key in the
repo-root .env.
"""
import csv
import gzip
import http.client
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(HERE)
RAW = os.path.join(HERE, "raw")
DATA = os.path.join(HERE, "data")
OUT = os.path.join(DATA, "state_imports_hs6.csv.gz")
OUT_HS6 = os.path.join(DATA, "hs6_descriptions.csv")
OUT_CTY = os.path.join(DATA, "countries.csv")

API = "https://api.census.gov/data/timeseries/intltrade/imports/"
START = "2025-01"
WORKERS = 6
TRIES = 5

# general imports; imports for consumption and transport-mode values alongside
VALS = {"value_usd": "GEN_VAL_MO", "con_val_usd": "CON_VAL_MO",
        "air_val_usd": "AIR_VAL_MO", "ves_val_usd": "VES_VAL_MO",
        "cnt_val_usd": "CNT_VAL_MO"}
COLUMNS = ["state", "year", "month", "cty_code", "hs6", *VALS]


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


def get(endpoint, params, key):
    """Return the API response as a list of dicts; [] when nothing matches."""
    url = API + endpoint + "?" + urllib.parse.urlencode({**params, "key": key})
    for attempt in range(1, TRIES + 1):
        try:
            with urllib.request.urlopen(url, timeout=600) as resp:
                body = resp.read().decode("utf-8")
            break
        except (urllib.error.URLError, http.client.HTTPException,
                TimeoutError, ConnectionError) as err:
            if attempt == TRIES or getattr(err, "code", 500) < 500:
                raise
            time.sleep(30 * attempt)
    if not body.strip():        # the API answers 204/empty when nothing matches
        return []
    header, *rows = json.loads(body)
    return [dict(zip(header, r)) for r in rows]


def lookups(key):
    """Write the HS6 and country lookup files; return the released months."""
    hs6, months = {}, set()
    for r in get("hs", {"get": "I_COMMODITY,I_COMMODITY_LDESC", "COMM_LVL": "HS6",
                        "CTY_CODE": "-", "time": "from " + START}, key):
        hs6[r["I_COMMODITY"]] = r["I_COMMODITY_LDESC"].strip()
        months.add(r["time"])
    cty = {}
    for r in get("hs", {"get": "CTY_CODE,CTY_NAME", "I_COMMODITY": "-",
                        "SUMMARY_LVL": "DET", "time": "from " + START}, key):
        if r["CTY_CODE"] != "-":
            cty[r["CTY_CODE"]] = r["CTY_NAME"].strip()
    for path, head, table in [(OUT_HS6, ["hs6", "hs6_desc"], hs6),
                              (OUT_CTY, ["cty_code", "cty_name"], cty)]:
        with open(path, "w", encoding="utf-8", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(head)
            w.writerows(sorted(table.items()))
    return sorted(months)


def states(key, month):
    rows = get("statehs", {"get": "STATE", "I_COMMODITY": "-", "CTY_CODE": "-",
                           "time": month}, key)
    return sorted(r["STATE"] for r in rows if r["STATE"] != "-")


def raw_path(state, month):
    return os.path.join(RAW, f"imports_{state}_{month}.json.gz")


def fetch(state, month, key):
    rows = get("statehs", {"get": "I_COMMODITY,CTY_CODE," + ",".join(VALS.values()),
                           "COMM_LVL": "HS6", "SUMMARY_LVL": "DET",
                           "STATE": state, "time": month}, key)
    tmp = raw_path(state, month) + ".part"
    with gzip.open(tmp, "wt", encoding="utf-8") as fh:
        json.dump(rows, fh)
    os.replace(tmp, raw_path(state, month))
    return len(rows)


def main():
    refresh = "--refresh" in sys.argv[1:]
    key = api_key()
    os.makedirs(RAW, exist_ok=True)
    os.makedirs(DATA, exist_ok=True)

    months = lookups(key)
    codes = states(key, months[-1])
    print(f"{len(codes)} state codes, {months[0]} to {months[-1]}")

    todo = [(s, m) for s in codes for m in months
            if refresh or not os.path.exists(raw_path(s, m))]
    print(f"{len(todo)} state-months to fetch")
    with ThreadPoolExecutor(WORKERS) as pool:
        jobs = {pool.submit(fetch, s, m, key): (s, m) for s, m in todo}
        for n, job in enumerate(as_completed(jobs), 1):
            s, m = jobs[job]
            print(f"[{n}/{len(todo)}] {s} {m}: {job.result()} rows", flush=True)

    written = dropped = 0
    with gzip.open(OUT, "wt", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=COLUMNS)
        w.writeheader()
        for s in codes:
            for m in months:
                with gzip.open(raw_path(s, m), "rt", encoding="utf-8") as raw:
                    rows = json.load(raw)
                year, month = m.split("-")
                out = []
                for r in rows:
                    if r["CTY_CODE"] == "-":        # all-country total
                        continue
                    vals = {col: int(r[var]) for col, var in VALS.items()}
                    if not any(vals.values()):      # year-to-date padding
                        dropped += 1
                        continue
                    out.append({"state": s, "year": int(year), "month": int(month),
                                "cty_code": r["CTY_CODE"], "hs6": r["I_COMMODITY"],
                                **vals})
                out.sort(key=lambda r: (r["cty_code"], r["hs6"]))
                w.writerows(out)
                written += len(out)
    print(f"wrote {written} rows to {OUT} ({dropped} all-zero rows dropped)")


if __name__ == "__main__":
    main()
