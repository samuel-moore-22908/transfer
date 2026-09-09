"""Build data/canton_named/ — IGN canton polygons carrying INSEE canton names.

Geometry comes from data/canton/CANTON.shp (IGN ADMIN EXPRESS COG CARTO 3.2,
edition 2024-02-22, WGS84) and is copied through unchanged; only the DBF is
rewritten. Names come from the INSEE COG 2024 canton table, joined on
INSEE_DEP + INSEE_CAN.

    pip install pyshp
    python scripts/build_canton_named.py

The INSEE CSV is downloaded into raw/ on first run. Re-extracting the IGN
geometry is documented in README.md.
"""
import csv
import os
import shapefile
import urllib.request

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(HERE, "data", "canton", "CANTON")
OUT = os.path.join(HERE, "data", "canton_named", "CANTON_NAMED")
INSEE_URL = "https://www.insee.fr/fr/statistiques/fichier/7766585/v_canton_2024.csv"
INSEE_CSV = os.path.join(HERE, "raw", "v_canton_2024.csv")

os.makedirs(os.path.join(HERE, "raw"), exist_ok=True)
if not os.path.exists(INSEE_CSV):
    print("downloading", INSEE_URL)
    urllib.request.urlretrieve(INSEE_URL, INSEE_CSV)

with open(INSEE_CSV, encoding="utf-8", newline="") as fh:
    ref = {row["CAN"]: row for row in csv.DictReader(fh)}

os.makedirs(os.path.dirname(OUT), exist_ok=True)
r = shapefile.Reader(SRC, encoding="utf-8")
w = shapefile.Writer(OUT, shapeType=shapefile.POLYGON, encoding="utf-8")
w.field("ID", "C", 24)
w.field("CAN_CODE", "C", 5)      # INSEE_DEP + INSEE_CAN, unique national key
w.field("INSEE_CAN", "C", 5)
w.field("INSEE_DEP", "C", 3)
w.field("INSEE_REG", "C", 2)
w.field("NOM", "C", 70)          # INSEE LIBELLE
w.field("NOM_MAJ", "C", 70)      # INSEE NCC (uppercase, unaccented)
w.field("BURCENTRAL", "C", 5)    # commune code of the bureau centralisateur

unmatched = []
for sr in r.iterShapeRecords():
    rec = sr.record
    key = (rec["INSEE_DEP"] or "").strip() + (rec["INSEE_CAN"] or "").strip()
    m = ref.get(key)
    if m is None:
        unmatched.append(key)
    w.shape(sr.shape)
    w.record(rec["ID"], key, rec["INSEE_CAN"], rec["INSEE_DEP"], rec["INSEE_REG"],
             m["LIBELLE"] if m else "", m["NCC"] if m else "",
             m["BURCENTRAL"] if m else "")
w.close()

with open(OUT + ".cpg", "w") as fh:
    fh.write("UTF-8")
with open(OUT + ".prj", "w") as fh, open(SRC + ".prj") as src_prj:
    fh.write(src_prj.read())

print(f"{len(r)} polygons written; {len(unmatched)} without an INSEE name: {unmatched}")
