"""Build data/canton_2025_dom_rapproches/ from IGN's 2025 canton GeoJSON.

WARNING: in this source the overseas departments are MOVED next to metropolitan
France ("DOM rapprochés") so the whole country fits one frame. Guadeloupe sits
at ~4W/46N, Reunion at ~3W/42N, Mayotte at ~0E/41N. Use it for national maps,
never for real-world coordinates, distances or spatial joins.

    pip install pyshp
    python scripts/build_canton_2025_dom_rapproches.py

The GeoJSON is downloaded into raw/ on first run.
"""
import json
import os
import shapefile
import urllib.request

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "data", "canton_2025_dom_rapproches", "CANTON_2025_DOM_RAPPROCHES")
SRC_URL = ("https://static.data.gouv.fr/resources/"
           "communes-cantons-et-epci-2025-admin-express-cog-plus-ign/"
           "20250626-075229/a-can2025.geojson")
SRC = os.path.join(HERE, "raw", "a_can2025.geojson")

os.makedirs(os.path.join(HERE, "raw"), exist_ok=True)
if not os.path.exists(SRC):
    print("downloading", SRC_URL)
    urllib.request.urlretrieve(SRC_URL, SRC)

with open(SRC, encoding="utf-8") as fh:
    feats = json.load(fh)["features"]


def signed_area(ring):
    s = 0.0
    for i in range(len(ring) - 1):
        x1, y1 = ring[i][0], ring[i][1]
        x2, y2 = ring[i + 1][0], ring[i + 1][1]
        s += x1 * y2 - x2 * y1
    return s / 2.0


def orient(ring, want_cw):
    """Shapefiles want shells clockwise and holes counter-clockwise; GeoJSON is the reverse."""
    r = [(p[0], p[1]) for p in ring]
    if r[0] != r[-1]:
        r.append(r[0])
    a = signed_area(r)
    if (want_cw and a > 0) or (not want_cw and a < 0):
        r.reverse()
    return r


os.makedirs(os.path.dirname(OUT), exist_ok=True)
w = shapefile.Writer(OUT, shapeType=shapefile.POLYGON, encoding="utf-8")
w.field("CODGEO", "C", 5)
w.field("LIBGEO", "C", 100)
w.field("DEPT", "C", 3)
w.field("REG", "C", 3)
w.field("COMPOSITIO", "C", 60)

for f in feats:
    rings = []
    for poly in f["geometry"]["coordinates"]:            # MultiPolygon
        for i, ring in enumerate(poly):
            rings.append(orient(ring, want_cw=(i == 0)))  # first ring is the shell
    w.poly(rings)
    p = f["properties"]
    w.record(p["codgeo"], p["libgeo"], p["dept"], p["reg"], p["composition"])
w.close()

with open(OUT + ".cpg", "w") as fh:
    fh.write("UTF-8")
with open(OUT + ".prj", "w") as fh:
    fh.write('GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,'
             '298.257223563]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]]')

print(f"{len(feats)} polygons written")
