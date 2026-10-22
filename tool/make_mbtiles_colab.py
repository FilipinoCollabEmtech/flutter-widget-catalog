# Google Colab script: build an offline raster .mbtiles for Cebu City.
#
# HOW TO RUN
#  1. Open https://colab.research.google.com/ (a new notebook)
#  2. Paste this whole cell into a code cell
#  3. Shift+Enter to run
#  4. When it finishes, the file downloads to your machine
#
# Tweak MIN_LON/MAX_LON/MIN_LAT/MAX_LAT and MIN_Z/MAX_Z to change the area
# or zoom coverage, then re-run.

import math
import os
import sqlite3
import time
import urllib.request

# --- CONFIG ---------------------------------------------------------------
MIN_LON, MIN_LAT, MAX_LON, MAX_LAT = 123.58, 10.08, 124.12, 10.52
MIN_Z, MAX_Z = 10, 15
OUT = "/content/cebu_city.mbtiles"
BASE = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile"
ATTRIBUTION = "Esri, Maxar, Earthstar Geographics, OpenStreetMap contributors"
UA = "SeeRutaThesisPrototype/1.0 (university research prototype, low volume)"
DELAY = 0.05  # be polite to the tile server
# ---------------------------------------------------------------------------


def deg2num(lon, lat, z):
    n = 2 ** z
    xt = int((lon + 180.0) / 360.0 * n)
    lat_r = math.radians(lat)
    yt = int((1.0 - math.asinh(math.tan(lat_r)) / math.pi) / 2.0 * n)
    return xt, yt


def fetch(url, tries=3):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=30) as r:
                if r.status == 200:
                    return r.read()
        except Exception:
            time.sleep(1.0)
    return None


jobs = []
for z in range(MIN_Z, MAX_Z + 1):
    xa, ya = deg2num(MIN_LON, MAX_LAT, z)
    xb, yb = deg2num(MAX_LON, MIN_LAT, z)
    for x in range(min(xa, xb), max(xa, xb) + 1):
        for y in range(min(ya, yb), max(ya, yb) + 1):
            jobs.append((z, x, y))

print(f"tiles to fetch: {len(jobs)}")

if os.path.exists(OUT):
    os.remove(OUT)
con = sqlite3.connect(OUT)
cur = con.cursor()
cur.execute("CREATE TABLE metadata (name TEXT PRIMARY KEY, value TEXT)")
cur.execute(
    "CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, "
    "tile_row INTEGER, tile_data BLOB, "
    "PRIMARY KEY (zoom_level, tile_column, tile_row))"
)
meta = {
    "name": "cebu",
    "format": "jpg",
    "minzoom": str(MIN_Z),
    "maxzoom": str(MAX_Z),
    "bounds": f"{MIN_LON},{MIN_LAT},{MAX_LON},{MAX_LAT}",
    "center": f"{(MIN_LON + MAX_LON) / 2},{(MIN_LAT + MAX_LAT) / 2},{MIN_Z}",
    "attribution": ATTRIBUTION,
    "type": "baselayer",
    "version": "1",
}
cur.executemany("INSERT INTO metadata (name, value) VALUES (?, ?)", list(meta.items()))

ok, fail = 0, 0
for i, (z, x, y) in enumerate(jobs):
    data = fetch(f"{BASE}/{z}/{y}/{x}")
    if data:
        # MBTiles stores rows in TMS order (flipped vertically).
        tms_y = (2 ** z - 1) - y
        cur.execute(
            "INSERT OR REPLACE INTO tiles VALUES (?, ?, ?, ?)", (z, x, tms_y, data)
        )
        ok += 1
    else:
        fail += 1
    if (i + 1) % 200 == 0:
        print(f"  {i + 1}/{len(jobs)} ok={ok} fail={fail}", flush=True)
    time.sleep(DELAY)

con.commit()
con.close()
size_mb = os.path.getsize(OUT) / 1e6
print(f"DONE tiles={ok} failed={fail} size={size_mb:.1f}MB -> {OUT}")

from google.colab import files

files.download(OUT)
