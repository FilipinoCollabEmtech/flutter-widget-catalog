# Project Context: flutter-widget-catalog / SeeRuta offline vector map

Last updated: 2026-10-27

## Goal

Fix the offline **vector** map so it works in the app, and give it a fuller map
style (roads, landuse, buildings, labels) using the existing
`assets/maps/cebu_city.mbtiles`. The user only edits `lib/` and `assets/`; a
teammate or the GitHub Actions workflow builds the APK.

## Hard rules from the user

- **Do not guess.** Ask clarifying questions (use the `question` tool) before
  making assumptions that change behavior.
- Keep the workspace to `lib/` and `assets/` only. Do not restore `pubspec.yaml`,
  `analysis_options.yaml`, `android/`, etc.
- The teammate/workflow handles building. Local build files are intentionally
  absent.
- Leave these untracked extras alone (do not clone/copy them):
  `.and-code/`, `ENVIRONMENT_CAPABILITIES.md`,
  `google-cloud-cli-linux-arm.tar.gz`, `google-cloud-sdk/`.

## Repository / source of truth

- Remote: https://github.com/FilipinoCollabEmtech/flutter-widget-catalog.git
- Local workspace: `C:\Users\Adminator\Documents\SeeRuta\teammate` (IS a git
  clone, has `.git/`).
- Latest commit: `9abbe6d` on `map_on_home` (not yet on `main`). Message:
  "fix: resolve all flutter analyze errors + pinch-zoom optimizations +
  debug telemetry".
- `main` is at `b3bc95a` ("fix: keep cebu boundary blur aligned when map is
  rotated or tilted").
- Earlier relevant commits: `21a79c7` (stable APK signing with a fixed release
  keystore) and `ace5ec09` (full OSM Liberty theme).
- Earlier vector migration: `4e0c7e630d29821321a0ea7bea6f1f8105c9b2d4`
  ("Migrate offline map from raster MBTiles to vector MBTiles (MVT) for Cebu").
- The Flutter build workflow (`.github/workflows/flutter.yml`) triggers on
  pushes to `main` only (coworker switched it from `map_on_home` to `main`).
- A separate BETA workflow (`.github/workflows/flutter_beta.yml`) triggers on
  pushes to `map_on_home` and publishes releases tagged `build-beta-<sha>`.
- Debug and release APKs are signed with the same fixed release key stored in
  GitHub Actions secrets (`ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`).
  `android/app/build.gradle.kts` reads `android/key.properties`; the workflow
  writes it from secrets before building.
- Application ID changed to `org.research.seeruta`, app name "SeeRuta" (restored
  by coworker in commit `56f8a00`).
- Latest GitHub release tag: `build-5434c65ae14663423184b124c4fa4123e3847de3`.

## Recent branch history (2026-10-25 to 2026-10-27)

- `main` was at `3c061b5` ("layout: changing ui cause yea"), workflow run
  `40175035356` succeeded.
- `map_on_home` was at `4e0c7e63`, diverged from `main`.
- Commit `dac7c83` was created on `map_on_home` (offline vector map + worker
  isolate provider + trimmed theme + Admin tab).
- Pushed `map_on_home` → triggered workflow run `40175995198` (**success**,
  head_branch `map_on_home`, head_sha `dac7c83`).
- Per user instruction, force-pushed `map_on_home:main` (`3c061b5` → `dac7c83`),
  replacing the 7 commits that were ahead on `main`. Both branches now point at
  `dac7c83`.
- Note: the force-push overwrote main-only commits
  (5879db6, 292e8ec, 20ea044, 6b24999, 99a09ae, f615208, a23339f).
- Coworker pushed UI updates + sqlite fix on top:
  - `0636524` - fix: add sqlite3_flutter_libs so libsqlite3.so is bundled
  - `56f8a00` - fix: bundle sqlite3_flutter_libs, restore SeeRuta identity +
    release signing
  - `a6bd366` - changed: UI layout for future uses (curved nav bar, main.dart
    UI updates)
- Both `main` and `map_on_home` now at `a6bd366`.
- Commit `b3bc95a` ("fix: keep cebu boundary blur aligned when map is
  rotated or tilted") applied a camera rotation transform to the
  `_OutsidePainter` canvas so the Cebu boundary blur stays aligned with
  the map view when tilted or rotated. Pushed to both `main` and
  `map_on_home`; workflow run `40366412794` succeeded.
- Commit `fe5d674` ("fix: reduce pinch-and-zoom tile churn") on `map_on_home`
  only:
  - `maximumTileSubstitutionDifference` 3 → 0 so vector layer only uses
    exact zoom tiles, no ±3 level substitution during pinch
  - Gesture-aware tile loading: during active pinch, tile reads use 2s
    timeout instead of 15s so obsolete intermediate-zoom requests don't
    flood the worker isolate
  - `onPositionChanged` `hasGesture` wired to `provider.setGestureActive()`
  - NOT on `main` yet (main is for final fixed versions)
- Commit `c8dfd20` ("feat: replace admin page slot with camera demo; admin
  replaces profile after Konami; add debug telemetry") on `map_on_home` only:
  - Page slot 1: `CameraDemoPage` placeholder (camera button, coming soon)
    replaces the Admin page slot
  - Page slot 2: Profile normally, `AdminPage` after Konami unlock replaces
    it (Admin replaces Profile)
  - Bottom nav right: Admin button replaces Profile button after Konami
  - Admin page: live telemetry (gate limit/active/queued, max zoom, provider
    type), app info, debug switches (force tile reload, refresh stats)
  - HomePage: periodic telemetry ticker (1s) updates debugStats with tile
    gate stats so Admin page shows live data
  - NOT on `main` yet (main is for final fixed versions)
- Commit `cde6ef0` ("feat: replace UI with pill nav bar from Uploaded_CodesDONTOPEN!!")
  on `map_on_home` only:
  - Replaced `CurvedNavBar` with `PillNavBar` widget
    (`lib/widgets/pill_nav_bar.dart`): floating rounded bottom bar with raised
    center button, 2 left + 2 right buttons
  - `lib/main.dart`: add dark theme, `extendBody` so map flows behind bar,
    center button is "My Location"
  - Page indices: 0 = Home, 1 = Camera demo, 2 = Profile/Admin slot,
    3 = Barangay route
  - Bottom nav left: Home + Barangays; right: Camera + Profile/Admin
  - NOT on `main` yet
- Commit `a3b0d1c` ("change:ui: burger menu dropdown pops out of burger menu")
  on `map_on_home` only
- Commit `39fbdde` (merge) on `map_on_home` only
- Commit `18bbc64` ("feat: add cebu barangay boundaries geojson") on `map_on_home`
  only:
  - Downloaded `barangays.geojson` (63.8 MB, 42,026 PH barangays) from
    https://github.com/bendlikeabamboo/barangay-boundaries-repository/releases/download/v2026.4.13.0
  - Filtered to Cebu province only (`ADM2_EN == 'Cebu'`): **1,203 barangays**
  - Saved to `assets/maps/barangays.geojson` (~1 MB)
  - Declared in `pubspec.yaml` under `flutter.assets`
  - NOT on `main` yet
- Commit `9abbe6d` ("fix: resolve all flutter analyze errors + pinch-zoom optimizations +
  debug telemetry") on `map_on_home` only:
  - MbtilesVectorTileProvider: tile generation tracking (discard stale reads),
    100ms pinch debounce per tile, request deduplication, worker timeout 2s
    during pinch, debug telemetry logging via ValueNotifier
  - AdaptiveTileGate: pinch mode drops concurrency to 1 during active pinch
  - HomePage: wire setPinchMode to gesture state, add tile gate/telemetry stats
  - AdminPage: debug telemetry switch, layer visibility toggles for each map
    layer, live stats display
  - home_page.dart: wire setPinchMode to gesture state, wrap layers with
    ValueListenableBuilder
  - barangay_route_page.dart: worker isolate tile provider, per-layer visibility
    toggles, route polyline visibility toggle, cebu boundary + direction arrow
    visibility toggles
  - pubspec.yaml: declare assets/maps/barangays.geojson
  - Flutter analyze: 0 errors

## Current workspace state

- `lib/` — includes: `home_page.dart`, `mbtiles_vector_tile_provider.dart`,
  `adaptive_tile_gate.dart`, `admin_page.dart`, `cebu_boundary_layer.dart`,
  `curved_nav_bar.dart`, `pill_nav_bar.dart` (new), `camera_demo_page.dart`,
  `barangay_route_page.dart` (new), `models/barangay.dart` (new),
  `services/barangay_service.dart` (new), `animated_map_mover.dart`,
  `location_service.dart`, `user_location_layer.dart`, `profile_page.dart`,
  `grave_particles.dart`, `konami.dart`
- `assets/` — 75.1 MB:
  - `assets/maps/cebu_city.mbtiles` — 41,250,816 bytes (vector, used by app)
  - `assets/maps/barangays.geojson` — ~1 MB (1,203 Cebu barangays, NEW)
  - `assets/cebu.mbtiles` — 37,486,592 bytes (raster JPG, unused by app)
- `CONTEXT.md` — this file
- `.github/workflows/flutter.yml` — workflow file (triggers on `main`)
- `.github/workflows/flutter_beta.yml` — workflow file (triggers on `map_on_home`)
- Untracked (not committed): `.vscode/`, `lib/CONTEXT.md`, `main.dart` (root),
  `launch-opencode-server.vbs`, `start-opencode-server.bat`, `logs.zip`,
  `logs_clean.zip`, `workflow_logs.txt`
- Modified & committed on `9abbe6d`: `lib/main.dart`, `lib/pages/home_page.dart`,
  `lib/widgets/pill_nav_bar.dart`, `lib/models/barangay.dart` (new),
  `lib/services/barangay_service.dart` (new), `lib/pages/barangay_route_page.dart`
  (new), `lib/pages/admin_page.dart` (modified), `lib/pages/mbtiles_vector_tile_provider.dart`
  (modified), `lib/pages/adaptive_tile_gate.dart` (modified),
  `pubspec.yaml` (adds barangays.geojson asset),
  `assets/maps/barangays.geojson` (new).
- No local `flutter`/`dart` commands can run (no Flutter SDK in workspace).
- Environment tools: `python3` is available; `flutter`, `dart`, `tilemaker`,
  `tippecanoe`, `ogr2ogr` are NOT installed. Python geo libs
  (`mapbox_vector_tile`, `osmium`, `shapely`, `mercantile`, `pmtiles`, `pyproj`)
  are NOT installed.
- Leftover temp dirs in `/tmp/opencode/` (`fwc-latest`, `fwc-old-git`) could not
  be fully deleted due to "Operation not permitted" stale `.l2s.tmp_*` files in
  their `.git` pack dirs. Outside the workspace; harmless.

## App flow (relevant code)

`lib/pages/home_page.dart`:

1. `_loadOfflineMap()` gets `getApplicationSupportDirectory()`.
2. Target file: `<appSupport>/cebu_city.mbtiles`.
3. If it does not exist, loads `assets/maps/cebu_city.mbtiles` via `rootBundle`
   and writes it.
   - **Important:** it does NOT overwrite an existing file. A stale/corrupt copy
     from a previous install (e.g. the old raster file) would remain and cause
     confusing errors.
4. Creates `MbtilesVectorTileProvider.create(mbtilesPath: ..., maxZoom: 14)`,
   which spawns a long-lived worker isolate and opens the SQLite DB there.
5. Renders `VectorTileLayer(tileProviders: {'openmaptiles': provider},
   theme: _vectorThemeInstance, layerMode: vector, maximumZoom: 14,
   concurrency: 6, larger memory/file caches,
   maximumTileSubstitutionDifference: 1)`.
6. Any exception during the load is caught and shown in the map area as
   `Failed to load offline map:\n<error>` (`_mapError`).
7. `_isPinching` flag + `_tileProvider?.setGestureActive(hasGesture)` wired to
   `onPositionChanged` for pinch-aware tile loading.
8. 1s periodic telemetry ticker updates `debugStats` (gate limit/active/queued,
   max zoom, provider type) via `widget.debugStats`.

Map style (changed 2026-10-25, commit `dac7c83`):

- `home_page.dart` starts from `vtr.ProvidedThemes.lightTheme()` (full OSM
  Liberty, ~102 layers) and removes the most expensive layers via
  `_buildOfflineTheme()`:
  - Dropped: POIs (`poi*`), 3D buildings (`building-3d`), shields
    (`road_shield*`, `highway-shield`), one-way arrows (`road_one_way*`),
    country/continent labels (`label_country*`, `label_continent*`),
    `natural_earth` raster, `place_other`, airport layer.
  - Kept: background, landcover/landuse, park, water/waterway, aeroway, all
    road/tunnel/bridge casings and fills, flat `building`, boundaries, and
    water/road/place (city/town/village) labels.
- This still matches the OpenMapTiles 3.x schema in the MBTiles file.
- Buildings only appear at zoom 13+ (data has `building` from z13); roads are
  visible from z11 (primary/trunk/secondary/tertiary) and more at z12+.
- Labels use `name`/`name_en` and render with Flutter's default font fallback
  (the theme's Roboto names are not bundled). Sprites/icons are not supplied.
- The provider throws `ProviderException(statusCode: 404)` for missing tiles,
  so `vector_map_tiles` renders empty tiles at edges/overzoom.
- Added: Cebu boundary layer (`CebuOutsideLayer`), direction arrow
  (`CebuDirectionArrow`), Admin tab (Konami unlock preserved from Demo tab),
  zoom readout (debug, toggle in Admin tab).
- Coworker added: `CurvedNavBar` widget (replaced by `PillNavBar` in
  `cde6ef0`), updated `lib/main.dart` shell UI.

`lib/pages/barangay_route_page.dart` (NEW):

- Route-aware barangay overlay using `assets/maps/barangays.geojson`.
- Tap map to add route waypoints (blue polyline connects them).
- Barangays the route passes through highlight orange; seen ones turn green.
- Tap a highlighted barangay → mark "seen" with optional note, persisted
  locally via `path_provider` (JSON in app documents dir).
- Bottom sheet lists seen barangays + on-route count.
- Floating action button recenters to first barangay.

`lib/models/barangay.dart` (NEW):

- `Barangay` class: name, code, polygon (List<LatLng>), seen flag, note,
  `contains(point)` point-in-polygon test, `centroid`, `bounds`.
- `RoutePlan` class: waypoints list, `passesThrough(barangay)` — samples points
  along each segment (~50 m apart) and checks if any fall inside the barangay
  polygon. Also does bounding-box quick reject and Haversine distance.

`lib/services/barangay_service.dart` (NEW):

- `BarangayService`: loads GeoJSON from `assets/maps/barangays.geojson`,
  persists seen tags to app documents dir (`barangay_seen.json`).
- `load()`: parses FeatureCollection, extracts Polygon outer ring,
  restores seen state from local JSON.
- `setSeen(code, seen, note?)`: marks barangay seen/unseen, persists.
- `setNote(code, note)`: updates note for seen barangay.
- `intersectedBy(route)`: returns barangays the route passes through.
- `seenList`: all seen barangays.

`lib/pages/mbtiles_vector_tile_provider.dart`:

- `create()` spawns a worker isolate via `Isolate.spawn`; the worker opens
  `MbTiles(mbtilesPath: ...)` from package `mbtiles`.
- The worker converts XYZ `y` to TMS (`tmsY = ((1 << z) - 1) - y`), calls
  `getTile(z, x, tmsY)`, and sends the bytes/error back over a `SendPort`.
- This keeps SQLite queries and gzip decoding off the UI isolate.
- `provide()` uses request IDs + `Completer`s and a 15 s timeout (2 s during
  active pinch), gated by `AdaptiveTileGate`.
- `maximumZoom = 14`, `minimumZoom = 0`, `type = TileProviderType.vector`.
- `dispose()` sends a dispose message, closes the port, kills the isolate.

`lib/main.dart` and other pages: App shell with bottom toolbar + drawer.
`main.dart` imports `admin_page.dart`, `barangay_route_page.dart`,
`camera_demo_page.dart` (replaced `demo_gallery.dart`).
- Page slot 0: `HomePage` with zoom readout + debug telemetry sink.
- Page slot 1: `CameraDemoPage` placeholder (camera button, coming soon).
- Page slot 2: `ProfilePage` normally, `AdminPage` after Konami unlock
  replaces it (Admin replaces Profile).
- Page slot 3: `BarangayRoutePage` (route-aware barangay map).
- Bottom nav left: Home + Barangays.
- Bottom nav right: Camera + Profile/Admin (Admin replaces Profile after Konami).
- `UserLocationLayer`/`LocationService` are unrelated to tiles.
- `PillNavBar` is the new bottom navigation bar (replaced `CurvedNavBar`).
- `HomePage` runs a 1s periodic telemetry ticker that updates `debugStats`
  with tile gate stats so the Admin page shows live data.

## Dependency versions (from main `pubspec.yaml`)

- `flutter_map: ^7.0.2`
- `vector_map_tiles: ^8.0.0`
- `vector_tile_renderer: ^5.2.0`
- `mbtiles: ^0.4.2`
- `sqlite3_flutter_libs: ^0.5.41`
- `path_provider: ^2.1.6`, `latlong2: ^0.9.0`, `geolocator: ^14.1.1`,
  `flutter_compass: ^0.8.1`, `http: ^1.2.0`
- Dart SDK constraint: `^3.13.5`

## MBTiles file facts (verified with Python sqlite3)

`assets/maps/cebu_city.mbtiles`:

- OpenMapTiles vector extract, metadata:
  - `format = pbf`, `minzoom = 0`, `maxzoom = 14`, `scheme = tms`
  - `bounds = 123.268,9.388,124.206,11.373`
  - `center = 123.737,10.3805,14`
  - `name = OpenMapTiles`, `version = 3.11`, id `openmaptiles`
  - planet date 2020-02-10 (old data)
- Schema is NOT the plain MBTiles `tiles` table. It has:
  - `metadata(name, value)`
  - `map(zoom_level, tile_column, tile_row, tile_id)` — 6,812 rows
  - `images(tile_id, tile_data)` — 6,469 rows, 5,337 distinct `tile_id`
  - `omtm(name, value)` — 5 rows
  - `tiles` is a **VIEW**:
    `SELECT map.*, images.tile_data FROM map JOIN images ON map.tile_id = images.tile_id`
- Because `images.tile_id` has duplicates, the view returns **1,063,924 rows**
  for 6,812 map rows. Duplicate `tile_id`s have identical `tile_data` (verified),
  so lookups are still correct, just inefficient.
- `PRAGMA integrity_check` = `ok`; `journal_mode = delete`; encoding UTF-8.
- Tile payloads are **gzip-compressed PBF** (magic `1f 8b`).
- Zoom tile counts per `map`: z0:1, z1:4, z2:16, z3:64, z4:256, z5:1024, z6:4,
  z7:4, z8:6, z9:8, z10:28, z11:78, z12:288, z13:1034, z14:3997.
- Layers present vary by zoom, including: `water`, `waterway`, `landcover`,
  `landuse`, `mountain_peak`, `park`, `boundary`, `aeroway`, `transportation`,
  `transportation_name`, `place`, `poi`, `building`, `housenumber`,
  `water_name`, `aerodrome_label`.
- Sample center tile (lat 10.3157, lon 123.8854):
  - z11 x1728 y964 (TMS 1083) — 19,963 bytes, layers: water, waterway,
    landcover, landuse, mountain_peak, transportation, place
  - z14 x13830 y7719 (TMS 8664) — 102,283 bytes

`assets/maps/barangays.geojson` (NEW — Cebu barangay boundaries):

- Source: https://github.com/bendlikeabamboo/barangay-boundaries-repository/
  releases/download/v2026.4.13.0/barangays.geojson (63.8 MB, 42,026 PH barangays)
- Filtered to Cebu province only (`ADM2_EN == 'Cebu'`): **1,203 features**
- Format: GeoJSON FeatureCollection, Polygon geometries
- Properties include: `ADM4_EN` (barangay name), `ADM4_PCODE`, `ADM3_EN`
  (city/municipality), `ADM2_PCODE` (`PH07022` = Cebu province),
  `psgc_code`, `psgc_name`, `AREA_SQKM`
- Used by `BarangayRoutePage` for route-aware territory overlay

`assets/cebu.mbtiles` (unused): raster Esri JPG basemap, `format=jpg`,
z9-15, 5,131 tiles, normal `metadata` + `tiles` table, integrity ok.

## Package behavior (verified from pub archives)

- `mbtiles` 0.4.2:
  - `MbTiles(...)` opens SQLite read-only, reads `SELECT * FROM metadata`.
  - `getTile()` runs
    `SELECT tile_data FROM tiles WHERE zoom_level=? AND tile_column=? AND tile_row=? LIMIT 1`.
  - It automatically **gzip-decodes** when metadata `format == 'pbf'`
    (`useGzip` default). So the provider does NOT need to gunzip manually.
- `vector_map_tiles` 8.0.0:
  - `VectorTileProvider.provide()` returns PBF/MVT bytes for
    `TileProviderType.vector`.
  - `VectorTileLayer` accepts `layerMode`, `maximumZoom` (raster only),
    `theme`, `tileProviders`.
  - Official `vector_map_tiles_mbtiles` provider does exactly the same XYZ→TMS
    conversion and returns raw bytes (no extra gunzip).
- `vector_tile_renderer` 5.2.0:
  - `ThemeReader().read(json)` supports background/fill/fill-extrusion/line/
    symbol/raster layers; logs warnings for unsupported layer types.
  - No gzip handling inside; decompression is expected in the tile provider
    (handled by `mbtiles` package here).

## Current symptom (confirmed)

UI loads fine, but the map area shows:

```
Failed to load offline map:
Invalid argument(s): Failed to load dynamic library
'/data/data/com.example.myapp/lib/libsqlite3.so':
dlopen failed: library "/data/data/com.example.myapp/lib/libsqlite3.so" not found
```

## Root cause (confirmed 2026-10-25)

- The released APK was built from **`map_on_home` at `4e0c7e63`**. That commit's
  `pubspec.yaml` has `mbtiles` but **not** `sqlite3_flutter_libs`.
- `mbtiles` 0.4.2 uses package `sqlite3`, which needs the native
  `libsqlite3.so`. Without `sqlite3_flutter_libs`, that `.so` is not bundled in
  the APK, so opening the MBTiles database throws the dlopen error above.
- Commit `e6c9c0bd` ("might fix libsqlite3.so error") added
  `sqlite3_flutter_libs: ^0.5.41` to `pubspec.yaml`, but only on **`main`**.
  `map_on_home` still points at `4e0c7e63` and does not contain that commit.
- `main` had both the vector map and the sqlite fix, plus a new application id
  (`org.research.seeruta`, app name "SeeRuta"). Installing a build from main
  gives a separate app from the old `com.example.myapp`, so it also avoids any
  stale `<appSupport>/cebu_city.mbtiles` from the old install.
  - **Note:** the 7 main-only commits were overwritten when `main` was
    force-updated to `dac7c83`.

## Fix chosen by the user

Permanently switch the Flutter build workflow to **`main`**:

- `/.github/workflows/flutter.yml` in this workspace was updated to trigger on
  `push`/`pull_request` to `main` (job name "Build APK (main)").
- This was **committed and pushed to `main`** as
  `91137aaf6c3298bdd7c7af1c3d2c1677537ec7fa`
  (message: "ci: build APK from main so sqlite3_flutter_libs is bundled").
- The push triggered workflow run `40158944241`, which **succeeded** in 6m26s
  and published release
  `build-91137aaf6c3298bdd7c7af1c3d2c1677537ec7fa`.
- The new release APK contains
  `lib/arm64-v8a/libsqlite3.so`, `lib/armeabi-v7a/libsqlite3.so`, and
  `lib/x86_64/libsqlite3.so`, so the dlopen error should be gone.
- Note: this file is outside the earlier "lib/assets only" rule, but the user
  explicitly chose this option.
- Coworker's commits `0636524` and `56f8a00` re-added
  `sqlite3_flutter_libs: ^0.5.41` to `pubspec.yaml` and restored SeeRuta
  signing identity. Commit `a6bd366` includes these fixes plus UI updates.

## APKs provided to the user

Latest performance build (use this one):

- `/storage/emulated/0/Chatcoding/app-release-perf-5434c65.apk`
- 97.8 MB (102,563,388 bytes), md5 `89102dfd7e38ce052c72ce560e324def`
- Source: GitHub release
  `build-5434c65ae14663423184b124c4fa4123e3847de3`, workflow run `40164540063`
  (succeeded), built from `main`.
- Contains `libsqlite3.so` for arm64-v8a, armeabi-v7a, x86_64.
- Signed with the stable release key (`CN=SeeRuta`, SHA-256
  `AC:75:B2:3F:08:B9:6B:08:6E:45:AD:37:DD:B7:65:DE:C5:EF:69:90:9F:9A:4B:D8:85:21:3A:30:07:F3:0B:32`).
- First build that uses the worker-isolate tile provider and the trimmed theme.

Signing-only build (stable key, before performance changes):

- `/storage/emulated/0/Chatcoding/app-release-signed-21a79c7.apk`
- 97.8 MB, md5 `6c07a93786778d6088c17162d3e9500a`
- Source: GitHub release
  `build-21a79c717de3acdbf49cb74bf62b417139512fc5`, workflow run `40163088734`.
- Verified v2 APK signature certificate matches the fixed keystore.
- If the user already installed an older SeeRuta build signed with the
  ephemeral GitHub runner debug key, they must uninstall it **once**. Builds
  from `21a79c7` onward share the same signature and update normally.

Previous full-style build (no performance changes):

- `/storage/emulated/0/Chatcoding/app-release-ace5ec09.apk`
- 97.8 MB (102,563,388 bytes), md5 `c24ae8e8dddd503fff169ec98b4bcd45`
- Source: GitHub release
  `build-ace5ec0981208f0b0254db9178a0a7d36c0cbfad`, workflow run `40160992531`
  (succeeded, 7m25s), built from `main`.

Previous sqlite-fixed build (map still had only 3 style layers):

- `/storage/emulated/0/Chatcoding/app-release-91137aaf.apk`
- 97.6 MB (102,317,628 bytes), md5 `7dd91a2a0c9fdb298751e74f2565f6fd`
- Source: GitHub release
  `build-91137aaf6c3298bdd7c7af1c3d2c1677537ec7fa`
- Built from `main`, includes `sqlite3_flutter_libs`; application id
  `org.research.seeruta` / name "SeeRuta" (separate from old
  `com.example.myapp` installs).
- Verified with Python zipfile: contains
  `lib/arm64-v8a/libsqlite3.so`, `lib/armeabi-v7a/libsqlite3.so`,
  `lib/x86_64/libsqlite3.so`.

Old broken build (kept only for reproducing the dlopen error):

- `/storage/emulated/0/Chatcoding/app-release-4e0c7e63.apk`
- 93.1 MB, md5 `d6e3d67123e38084012137cbabc54d07`
- Source: GitHub release `build-4e0c7e630d29821321a0ea7bea6f1f8105c9b2d4`
  (`app-release.apk`, 97,670,930 bytes), built from `map_on_home` without
  `sqlite3_flutter_libs`.
- A debug APK exists at the same release (200

## In-flight workflow (as of 2026-10-27)

- Workflow run `40370354083` — **success**, triggered by push of `c8dfd20`
  to `map_on_home` (camera demo + admin replaces profile + debug telemetry).
  head_branch `map_on_home`. BETA workflow (`flutter_beta.yml`).
  URL: https://github.com/FilipinoCollabEmtech/flutter-widget-catalog/actions/runs/40370354083
- Workflow run `40375842056` — **failure**, triggered by push of `c8dfd20`
  to `map_on_home` (Build APK debug failed: `ListTile` has no `secondary`
  param — fixed by changing to `leading` in admin_page.dart).
  URL: https://github.com/FilipinoCollabEmtech/flutter-widget-catalog/actions/runs/40375842056
- Workflow run `40380386507` — **success**, triggered by push of `ad63a5d`
  to `map_on_home` (fix: ListTile uses leading not secondary for icon).
  URL: https://github.com/FilipinoCollabEmtech/flutter-widget-catalog/actions/runs/40380386507
- Workflow run `40382722723` — **success**, triggered by push of `ed1faf8`
  to `map_on_home` (feat: add camera demo button beside profile/admin at
  bottom bar). BETA workflow (`flutter_beta.yml`).
  URL: https://github.com/FilipinoCollabEmtech/flutter-widget-catalog/actions/runs/40382722723
- Workflow run `40375842056` was the failing run for `c8dfd20`; fixed in
  `ad63a5d`, then `ed1faf8` added camera button, then `18bbc64` added Cebu
  barangay boundaries geojson.
