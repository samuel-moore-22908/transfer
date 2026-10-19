"""Build data/effective_tariffs_hs6.csv.gz — monthly US imports for consumption
by HS6 subheading and partner country, with calculated duties and the
effective tariff rate (duties / customs value), January 2025 to August 2026.

Source is USITC DataWeb (dataweb.usitc.gov), queried through its API:
    POST /dataweb/api/v2/report2/runReport
with CONS_CUSTOMS_VALUE and CONS_CALC_DUTY, commodities at HTS 6-digit,
countries broken out, monthly columns.

    python scripts/fetch_effective_tariffs.py            # resume
    python scripts/fetch_effective_tariffs.py --refresh  # refetch everything

One request per HS2 chapter and year. DataWeb refuses a request whose result
would be too large (it answers {"dto": null}), so such a chapter is split into
its HS4 headings, and a heading into its HS6 subheadings, found with a cheap
all-country query. Each response is saved, gzipped, into raw/; a rerun skips
pieces already there, so an interrupted pull picks up where it stopped.

Needs a DataWeb API token, read from DATAWEB_API_KEY or from dataweb_api_key
in the repo-root .env.
"""
import csv
import gzip
import http.client
import json
import os
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(HERE)
RAW = os.path.join(HERE, "raw")
DATA = os.path.join(HERE, "data")
OUT = os.path.join(DATA, "effective_tariffs_hs6.csv.gz")
OUT_HS6 = os.path.join(DATA, "hs6_descriptions.csv")

API = "https://datawebws.usitc.gov/dataweb/api/v2/report2/runReport"
# (year, first month, last month); DataWeb returns one table per year
PERIODS = [("2025", "01", "12"), ("2026", "01", "08")]
CHAPTERS = [f"{c:02d}" for c in range(1, 100) if c != 77]   # 77 is reserved
# DataWeb answers 429 to a sustained burst and sends no rate-limit headers, so
# requests go one at a time with a pause, and a 429 waits minutes, not seconds.
WORKERS = 1
PAUSE = 2
TRIES = 8

TABS = {"Customs Value": "customs_value_usd", "Calculated Duties": "calc_duty_usd"}
MONTHS = {m: i for i, m in enumerate(
    ["january", "february", "march", "april", "may", "june", "july", "august",
     "september", "october", "november", "december"], 1)}
COLUMNS = ["year", "month", "hs6", "country",
           "customs_value_usd", "calc_duty_usd", "effective_rate"]


def api_key():
    key = os.environ.get("DATAWEB_API_KEY")
    if key:
        return key
    with open(os.path.join(ROOT, ".env"), encoding="utf-8") as fh:
        for line in fh:
            name, _, value = line.strip().partition("=")
            if name.strip().lower() == "dataweb_api_key":
                return value.strip().strip("'\"")
    raise SystemExit("no DataWeb token: set DATAWEB_API_KEY or dataweb_api_key in .env")


def query(codes, granularity, by_country, period, data):
    """DataWeb runReport body: imports for consumption, HTS, the given codes."""
    year, first, last = period
    return {
        "savedQueryName": "", "savedQueryDesc": "", "isOwner": True, "runMonthly": False,
        "reportOptions": {"tradeType": "Import", "classificationSystem": "HTS"},
        "searchOptions": {
            "MiscGroup": {
                "districts": {"aggregation": "Aggregate District",
                              "districtGroups": {"userGroups": []}, "districts": [],
                              "districtsExpanded": [{"name": "All Districts", "value": "all"}],
                              "districtsSelectType": "all"},
                "importPrograms": {"aggregation": None, "importPrograms": [],
                                   "programsSelectType": "all"},
                "extImportPrograms": {"aggregation": "Aggregate CSC", "extImportPrograms": [],
                                      "extImportProgramsExpanded": [],
                                      "programsSelectType": "all"},
                "provisionCodes": {"aggregation": "Aggregate RPCODE",
                                   "provisionCodesSelectType": "all",
                                   "rateProvisionCodes": [],
                                   "rateProvisionCodesExpanded": []}},
            "commodities": {"aggregation": "Break Out Commodities", "codeDisplayFormat": "YES",
                            "commodities": codes, "commoditiesExpanded": [],
                            "commoditiesManual": ",".join(codes),
                            "commodityGroups": {"systemGroups": [], "userGroups": []},
                            "commoditySelectType": "list", "granularity": granularity,
                            "groupGranularity": None, "searchGranularity": None},
            "componentSettings": {"dataToReport": data, "scale": "1",
                                  "timeframeSelectType": "specificDateRange", "years": [],
                                  "startDate": f"{first}/{year}", "endDate": f"{last}/{year}",
                                  "startMonth": None, "endMonth": None,
                                  "yearsTimeline": "Monthly"},
            "countries": {"aggregation": "Break Out Countries" if by_country
                          else "Aggregate Countries",
                          "countries": [], "countriesSelectType": "all",
                          "countriesExpanded": [{"name": "All Countries", "value": "all"}],
                          "countryGroups": {"systemGroups": [], "userGroups": []}}},
        "sortingAndDataFormat": {
            "DataSort": {"columnOrder": [], "fullColumnOrder": [], "sortOrder": []},
            "reportCustomizations": {"exportCombineTables": False, "showAllSubtotal": True,
                                     "subtotalRecords": "", "totalRecords": "20000",
                                     "exportRawData": True}}}


def post(body, key):
    """Return the response's dto, or None when DataWeb declines the query."""
    req = urllib.request.Request(API, data=json.dumps(body).encode("utf-8"), method="POST",
                                 headers={"Content-Type": "application/json; charset=utf-8",
                                          "Authorization": "Bearer " + key})
    for attempt in range(1, TRIES + 1):
        time.sleep(PAUSE)
        try:
            with urllib.request.urlopen(req, timeout=600) as resp:
                dto = json.loads(resp.read().decode("utf-8"))["dto"]
            break
        except (urllib.error.URLError, http.client.HTTPException,
                TimeoutError, ConnectionError) as err:
            code = getattr(err, "code", 500)
            if attempt == TRIES or (code < 500 and code != 429):
                raise
            time.sleep((120 if code == 429 else 30) * attempt)
    if dto and dto["errors"]:
        raise RuntimeError(f"DataWeb rejected the query: {dto['errors']}")
    return dto


def rows(dto):
    """Yield (tab name, row values) for every data row of every table."""
    for table in dto["tables"]:
        for group in table["row_groups"]:
            labels = [c["queryResultLabel"] for c in group["columnInfo"]]
            for r in group["rowsNew"]:
                yield table["tableInfo"]["tabName"], dict(
                    zip(labels, (e["value"] for e in r["rowEntries"])))


def raw_path(year, code):
    return os.path.join(RAW, f"{year}_{code}.json.gz")


def split_path(year, code):
    return os.path.join(RAW, f"{year}_{code}.split.json")


def save(path, obj):
    tmp = path + ".part"
    with (gzip.open(tmp, "wt", encoding="utf-8") if path.endswith(".gz")
          else open(tmp, "w", encoding="utf-8")) as fh:
        json.dump(obj, fh)
    os.replace(tmp, path)


def fetch(period, code, key, refresh, log):
    """Fetch one code for one year, splitting it when DataWeb declines.

    Returns the leaf codes whose responses are in raw/.
    """
    year = period[0]
    if not refresh:
        if os.path.exists(raw_path(year, code)):
            return [code]
        if os.path.exists(split_path(year, code)):
            with open(split_path(year, code), encoding="utf-8") as fh:
                children = json.load(fh)
            return [leaf for c in children for leaf in fetch(period, c, key, refresh, log)]

    dto =post(query([code], "6", True, period,
                     ["CONS_CUSTOMS_VALUE", "CONS_CALC_DUTY"]), key)
    if dto is not None:
        save(raw_path(year, code), dto)
        log(f"{year} {code}: {sum(1 for _ in rows(dto)) // 2} rows")
        return [code]

    if len(code) >= 6:
        raise RuntimeError(f"DataWeb declined {year} {code} even at HS6")
    listing = post(query([code], str(len(code) + 2), False, period,
                         ["CONS_CUSTOMS_VALUE"]), key)
    children = sorted({r["hts"] for _, r in rows(listing)}) if listing else []
    if not children:
        raise RuntimeError(f"DataWeb declined {year} {code} and listed no subcodes")
    save(split_path(year, code), children)
    log(f"{year} {code}: too large, split into {len(children)} codes")
    return [leaf for c in children for leaf in fetch(period, c, key, refresh, log)]


def number(text):
    return int(text.replace(",", "")) if text not in ("", None) else 0


def main():
    refresh = "--refresh" in sys.argv[1:]
    key = api_key()
    os.makedirs(RAW, exist_ok=True)
    os.makedirs(DATA, exist_ok=True)

    jobs = [(p, c) for p in PERIODS for c in CHAPTERS]
    print(f"{len(jobs)} chapter-years, {PERIODS[0][1]}/{PERIODS[0][0]} "
          f"to {PERIODS[-1][2]}/{PERIODS[-1][0]}")
    done = [0]

    def log(msg):
        print(f"[{done[0]}/{len(jobs)}] {msg}", flush=True)

    def run(job):
        leaves = fetch(*job, key, refresh, log)
        done[0] += 1
        return job, leaves

    with ThreadPoolExecutor(WORKERS) as pool:
        results = list(pool.map(run, jobs))

    # Each raw file holds every HS6 x country row of one code-year, so it is
    # written out on its own; only one file is held in memory at a time.
    desc = {}
    written = dropped = 0
    with gzip.open(OUT, "wt", encoding="utf-8", newline="") as out:
        w = csv.DictWriter(out, fieldnames=COLUMNS)
        w.writeheader()
        for (period, _), leaves in results:
            year = int(period[0])
            for leaf in leaves:
                with gzip.open(raw_path(period[0], leaf), "rt", encoding="utf-8") as fh:
                    dto = json.load(fh)
                # (month, hs6, country) -> {column: value}
                cells = {}
                for tab, r in rows(dto):
                    desc[r["hts"]] = r["description"].strip()
                    for label, value in r.items():
                        if label in MONTHS:
                            cell = cells.setdefault((MONTHS[label], r["hts"], r["country"]), {})
                            cell[TABS[tab]] = number(value)
                del dto
                for (month, hs6, country), cell in sorted(cells.items()):
                    value = cell.get("customs_value_usd", 0)
                    duty = cell.get("calc_duty_usd", 0)
                    if not value and not duty:          # year-to-date padding
                        dropped += 1
                        continue
                    w.writerow({"year": year, "month": month, "hs6": hs6, "country": country,
                                "customs_value_usd": value, "calc_duty_usd": duty,
                                "effective_rate": f"{duty / value:.6f}" if value else ""})
                    written += 1
    with open(OUT_HS6, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["hs6", "hs6_desc"])
        w.writerows(sorted(desc.items()))
    print(f"wrote {written} rows to {OUT} ({dropped} all-zero rows dropped)")


if __name__ == "__main__":
    main()
