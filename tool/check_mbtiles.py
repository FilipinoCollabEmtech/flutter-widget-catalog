import sqlite3
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "assets/maps/cebu_city.mbtiles"
c = sqlite3.connect(path)
print("format:", c.execute("select value from metadata where name='format'").fetchone())
print("minzoom/maxzoom:", c.execute("select value from metadata where name in ('minzoom','maxzoom')").fetchall())
print("bounds:", c.execute("select value from metadata where name='bounds'").fetchone())
print("tiles:", c.execute("select count(*) from tiles").fetchone()[0])
print("zooms present:", c.execute("select distinct zoom_level from tiles order by zoom_level").fetchall())
print("sample sizes:", c.execute("select length(tile_data) from tiles limit 3").fetchall())
try:
    vl = c.execute("select value from metadata where name='vector_layers'").fetchone()
    print("vector_layers:", vl)
except Exception as e:
    print("vector_layers err:", e)
