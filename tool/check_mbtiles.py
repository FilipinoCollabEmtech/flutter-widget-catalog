"""Quick MBTiles inspector + CI guard.

SeeRuta's basemap and its MapLibre style must agree:
  - raster style  -> raster MBTiles (jpg/png/webp)
  - vector style  -> vector MBTiles (pbf/mvt)

A mismatch renders a blank map while the boundary/location overlays still
work, so CI fails before publishing an APK.

Usage:
    python3 tool/check_mbtiles.py [path] [--expect raster|vector]
"""

import argparse
import json
import sqlite3
import sys

parser = argparse.ArgumentParser()
parser.add_argument("path", nargs="?",
                    default="assets/maps/cebu_city.mbtiles")
parser.add_argument("--expect", choices=("raster", "vector"), default="raster")
args = parser.parse_args()

c = sqlite3.connect(args.path)
meta = dict(c.execute("select name, value from metadata").fetchall())
print("format:", meta.get("format"))
print("minzoom/maxzoom:", (meta.get("minzoom"), meta.get("maxzoom")))
print("bounds:", meta.get("bounds"))
print("tiles:", c.execute("select count(*) from tiles").fetchone()[0])
print("zooms present:", [r[0] for r in c.execute(
    "select distinct zoom_level from tiles order by zoom_level")])
print("sample sizes:", [r[0] for r in c.execute(
    "select length(tile_data) from tiles limit 3")])

vector_layers = meta.get("vector_layers")
if vector_layers is None and meta.get("json"):
    try:
        vector_layers = json.loads(meta["json"]).get("vector_layers")
    except json.JSONDecodeError:
        pass
if isinstance(vector_layers, list):
    print("vector_layers:", [layer.get("id") for layer in vector_layers])
else:
    print("vector_layers:", vector_layers)

formats = {
    "raster": ("jpg", "jpeg", "png", "webp"),
    "vector": ("pbf", "mvt"),
}
fmt = (meta.get("format") or "").lower()
if fmt not in formats[args.expect]:
    print(
        f"ERROR: {args.path} is '{fmt}', but the app style expects "
        f"{args.expect} tiles {formats[args.expect]}.",
        file=sys.stderr,
    )
    sys.exit(1)
