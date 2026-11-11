# Project Context: flutter-widget-catalog / SeeRuta offline vector map

Last updated: 2026-11-11 (verification pass — see "Verification log" at the end)

## How to read and maintain this file (AI agents, read first)

This file mixes **live facts**, **dated history**, and **opinions**. It WILL
drift. When you read it:

1. **Verify before you act.** Check every claim your task depends on against
   reality, not against this file: `git fetch` then compare `git branch -vv`
   with `origin/*`, `git log --oneline -5`, `git status`, `gh release list`,
   `gh run list`, file sizes, `flutter analyze`. Cheap checks beat wrong
   assumptions.
2. **If you find an inconsistency — inside this file, or between this file
   and the repo — REPLACE the wrong/stale part with the verified fact.**
   Do not keep both versions and do not just append a correction: delete the
   stale text so the file never contradicts itself.
3. **If the info is wrong (verified false), replace it too**, even if it
   looks authoritative. Write what you measured and when.
4. **Date-stamp every edit**: bump "Last updated" above, and update any
   "(as of ...)" marker you touched.
5. **History sections are append-only logs** ("Recent branch history",
   "Workflow run history", "APKs provided", "Verification log"). Add new
   entries at the bottom; mark superseded entries `(superseded)` rather than
   rewriting them.
6. Live sections you must keep truthful: this header, "Hard rules",
   "Repository / source of truth", "Current workspace state",
   "App flow", "Dependency versions".

## Goal

Fix the offline **vector** map so it works in the app, and give it a fuller map
style (roads, landuse, buildings, labels) using the existing
`assets/maps/cebu_city.mbtiles`. The user only edits `lib/` and `assets/`; a
teammate or the GitHub Actions workflow builds the APK.

## Hard rules from the user

- **Do not guess.** Ask clarifying questions (use the `question` tool) before
  making assumptions that change behavior.
- Keep edits scoped: the user primarily edits `lib/` and `assets/`. The
  build files (`pubspec.yaml`, `analysis_options.yaml`, `android/`, `.github/`)
  ARE present and tracked in this clone (verified 2026-11-11) — do not delete
  or "restore" them; only touch them when the task requires it (e.g. adding a
  dependency or asset declaration).
- The teammate/GitHub Actions workflow builds the APK (`.github/workflows/`
  triggers: `flutter.yml` → `main`, `flutter_beta.yml` → `map_on_home`,
  `build-mbtiles.yml` → manual `workflow_dispatch`). A local Flutter SDK is
  ALSO installed (`D:\Programs\flutter\bin\flutter.bat`) so `flutter analyze`
  can be run locally (verified 2026-11-11).
- Historical note: an older instruction said "workspace = lib/ + assets/ only,
  do not restore build files" — that described a period when those files were
  absent from the clone. It is no longer true; build files are tracked now.
- Leave these extras alone (do not clone/copy them into the workspace):
  `.and-code/`, `ENVIRONMENT_CAPABILITIES.md`, `google-cloud-cli-linux-arm.tar.gz`,
  `google-cloud-sdk/`. None of them exist in the workspace as of 2026-11-11 —
  keep it that way.

## Repository / source of truth

- Remote: https://github.com/FilipinoCollabEmtech/flutter-widget-catalog.git
- Local workspace: `C:\Users\Adminator\Documents\SeeRuta\teammate` (IS a git
  clone, has `.git/`).
- **Branch state (verified 2026-11-11 after `git fetch`):**
  - `origin/map_on_home` = `7de8c7b` ("updating README [skip actions]",
    2026-11-07) — this is the most advanced branch.
  - Local `map_on_home` (checked-out branch) = `ec5c5ab` (2026-10-28) —
    **14 commits BEHIND `origin/map_on_home`.** Do not assume local == remote.
  - `origin/main` = `b3bc95a` ("fix: keep cebu boundary blur aligned when map
    is rotated or tilted").
  - Local `main` = `5879db6` ("Merge map_on_home: vector MBTiles + vector
    provider") — **stale and diverged: ahead 7 / behind 6 vs `origin/main`**
    (its extra commits are the pre-force-push main-only commits listed below).
  - Also on remote: `origin/map_gpu_version` = `c98621d` (merged into
    `map_on_home` via PR #3, 2026-10-31).
- What the 14 remote-only commits changed (map_on_home): MapLibre migration
  (`maplibre_gl: ^0.27.1` + `lib/pages/cebu_map_view.dart`, `cebu_style.dart`,
  `offline_map_assets.dart` — MapLibre replaces flutter_map on Home), glyph
  fonts (`assets/glyphs/NotoSans{Regular,Medium,Italic}/`), pmtiles experiment
  (`65d22ef`) then revert (`8d49f50`), search-bar re-render fix (`1bdc966`),
  Codespaces `.devcontainer/`, `tool/build_apk.sh`, GPU workflow
  `.github/workflows/flutter_beta_gpu.yml`, Java 17→21 in workflows.
  Note: remote `pubspec.yaml` lists `assets/maps/cebu_city.mbtiles` twice
  (harmless duplicate).
- Earlier commits: `21a79c7` (stable APK signing with a fixed release
  keystore), `ace5ec09` (full OSM Liberty theme),
  `4e0c7e630d29821321a0ea7bea6f1f8105c9b2d4` (vector MBTiles migration),
  `e6c9c0bd` ("might fix libsqlite3.so error" — added sqlite3_flutter_libs on
  main only), `91137aaf` (ci: build APK from main). All exist in the object
  DB; `fe5d674`, `c8dfd20`, `ad63a5d`, `ed1faf8`, `dac7c83` are ancestors of
  local HEAD; `91137aaf`, `e6c9c0bd`, `21a79c7`, `ace5ec09` are NOT ancestors
  of local HEAD (they live on old main history reachable via tags).
- The Flutter build workflow (`.github/workflows/flutter.yml`) triggers on
  pushes/PRs to `main` (job display name still says "Build APK (map_on_home)"
  — display name only; trigger is `main`).
- A separate BETA workflow (`.github/workflows/flutter_beta.yml`) triggers on
  pushes/PRs to `map_on_home` and publishes releases tagged `build-beta-<sha>`.
  A third workflow `flutter_beta_gpu.yml` (remote only) publishes
  `build-gpu-test-<sha>`; `build-mbtiles.yml` is manual (`workflow_dispatch`).
- Debug and release APKs are signed with the same fixed release key stored in
  GitHub Actions secrets (`ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`).
  The workflow decodes the secret to `android/app/seeruta-release.p12` and
  writes `android/key.properties` (storeFile/storeType p12) before building;
  `android/app/build.gradle.kts` reads `rootProject.file("key.properties")`
  (i.e. `android/key.properties`). If secrets are missing, the build falls
  back to debug signing.
- Application ID `org.research.seeruta` (namespace + applicationId in
  `android/app/build.gradle.kts`), app label "SeeRuta"
  (`android/app/src/main/AndroidManifest.xml` `android:label`). NOTE:
  `pubspec.yaml` `name:` is still `myapp` and `lib/main.dart`
  `MaterialApp.title` is `'Widget Catalog'` (cosmetic leftovers).
- **Latest GitHub releases (verified 2026-11-11):** overall latest =
  `build-beta-6eabffffe047cecc769f6047d1c62dabb29d2a58` (2026-11-07, from
  `map_on_home`); latest non-beta = `build-b3bc95ac058ef61af4999a445a6115b7524a13a3`
  (2026-10-26, from `main`). The previously documented
  `build-5434c65ae14663423184b124c4fa4123e3847de3` (2026-10-25) still exists
  but is no longer the newest.

## Recent branch history (2026-10-25 to 2026-10-28)

> Append-only history. "now" statements below refer to that period, not to
> 2026-11-11 — see "Repository / source of truth" for current branch tips.

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
- Both `main` and `map_on_home` were then at `a6bd366` (as of 2026-10-27;
  both have moved since — `origin/main` → `b3bc95a`, `origin/map_on_home` →
  `7de8c7b`).
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

## Current workspace state (verified 2026-11-11)

- Checked-out branch: `map_on_home` @ `ec5c5ab`, **14 behind `origin/map_on_home`**
  (see "Repository / source of truth" for what the remote commits contain).
- `git status`:
  - modified: `CONTEXT.md` (this file)
  - deleted (still tracked): `launch-opencode-server.vbs`
  - untracked: `monitor-omegle-m3u8.ps1`, `monitor-omegle-m3u8-fast.ps1`,
    `monitor-omegle-m3u8.py`, `poll_beta.ps1`, `skills-lock.json`,
    `start-m3u8-monitor.bat`, `stop-m3u8-monitor.bat`, `stress.py`
  - ignored: `poll_beta.log` (`.gitignore` has `*.log`)
- `lib/` (21 Dart files):
  - App shell: `main.dart`
  - `pages/`: `home_page.dart`, `mbtiles_vector_tile_provider.dart`,
    `adaptive_tile_gate.dart`, `admin_page.dart`, `cebu_boundary_layer.dart`,
    `camera_demo_page.dart`, `barangay_route_page.dart`,
    `animated_map_mover.dart`, `location_service.dart`, `user_location_layer.dart`,
    `profile_page.dart`
  - `models/barangay.dart`, `services/barangay_service.dart`
  - `widgets/`: `pill_nav_bar.dart`, `konami.dart`, `grave_particles.dart`
  - **Orphaned files (exist but NOT imported by `main.dart` or anything else):**
    `pages/demo_gallery.dart`, `pages/barangay_map_page.dart`,
    `widgets/curved_nav_bar.dart` (replaced by `pill_nav_bar.dart`),
    `widgets/section_card.dart` (only used by `demo_gallery.dart`). Safe to
    delete, but confirm with the user first.
  - `lib/CONTEXT.md` also exists (tracked): it is a **stale verbatim copy of
    an older revision of the root `CONTEXT.md`** (last updated 2026-10-25,
    still contains the wrong "no Flutter SDK / build files absent" rules).
    The root `CONTEXT.md` is authoritative — do not read or trust the
    `lib/` copy; consider deleting it after confirming with the user.
- `assets/` — 2 files, 42,314,058 bytes (~40.3 MiB):
  - `assets/maps/cebu_city.mbtiles` — 41,250,816 bytes (vector, used by app)
  - `assets/maps/barangays.geojson` — 1,063,242 bytes (1,203 Cebu barangays)
  - NOTE: an older revision of this file claimed `assets/cebu.mbtiles`
    (37,486,592-byte raster, 75.1 MB total assets) — **that file no longer
    exists**; only the two files above are present. Also a 0-byte
    `cebu_city.mbtiles` sits at the repo ROOT (tracked, empty placeholder —
    not the asset; the real asset is `assets/maps/cebu_city.mbtiles`).
    Remote deleted the root `cebu_city.mbtiles`.
- Root extras (tracked): `CONTEXT.md`, `Features.md`, `README.md`,
  `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `start-opencode-server.bat`,
  `workflow_logs.txt`, `logs.zip`, `logs_clean.zip`, `.vscode/launch.json`,
  `lib/CONTEXT.md`. (An older revision listed these as untracked and listed a
  root `main.dart` — there is NO root `main.dart` and these ARE tracked.)
- `.github/workflows/`: `flutter.yml` (push/PR → `main`), `flutter_beta.yml`
  (push/PR → `map_on_home`), `build-mbtiles.yml` (manual `workflow_dispatch`).
  Remote also has `flutter_beta_gpu.yml`.
- **Local tools (verified 2026-11-11):**
  - `flutter` / `dart` ARE installed: `D:\Programs\flutter\bin\flutter.bat`
    (an older revision claimed no Flutter SDK — wrong now). `flutter analyze`
    runs locally: **0 errors, 4 info-level lints** in
    `lib/pages/mbtiles_vector_tile_provider.dart` (unnecessary `dart:typed_data`
    import + 3× `prefer_initializing_formals`). `flutter analyze` exits non-zero
    on info lints even though CI ignores it (`continue-on-error: true`).
  - `gh` (GitHub CLI) installed and authenticated; `python` 3.14.6 installed.
  - NOT installed: `tilemaker`, `tippecanoe`, `ogr2ogr`. Python geo libs NOT
    installed: `mapbox_vector_tile`, `osmium`, `shapely`, `mercantile`,
    `pmtiles`, `pyproj` (all verified `find_spec == None`).
  - MBTiles/GeoJSON verification scripts from the 2026-11-11 pass live in
    `%TEMP%\opencode\verify_context.py`, `verify_geo2.py`, `verify_mb3.py`,
    `lockver.py` (outside the workspace).

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
   concurrency: 6, caches: memoryTileCacheMaxSize 64 MiB,
   memoryTileDataCacheMaxSize 80, textCacheMaxSize 200,
   maximumTileSubstitutionDifference: 0)` (verified against
   `home_page.dart` 2026-11-11; an older revision of this file claimed `1` —
   wrong). Layers are wrapped in `ValueListenableBuilder`s driven by Admin
   toggles (`showVectorTiles`, `showCebuBoundary`, `showUserLocation`,
   `showCebuArrow`).
6. Any exception during the load is caught and shown in the map area as
   `Failed to load offline map:\n<error>` (`_mapError`).
7. Pinch wiring (verified 2026-11-11): `onPositionChanged(position, hasGesture)`
   calls `_mover.cancel()`, `_tileProvider?.setGestureActive(hasGesture)` and
   `_tileProvider?.gate.setPinchMode(hasGesture)`. There is NO `_isPinching`
   field anywhere in `lib/` (an older revision of this file claimed one —
   wrong). `setGestureActive` bumps the tile generation (discarding stale
   reads); `setPinchMode` drops the gate to 1 concurrent read.
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
- `load()`: parses FeatureCollection, extracts Polygon outer ring
  (MultiPolygon features are skipped — see the GeoJSON caveat above),
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

## Dependency versions (verified 2026-11-11)

> The heading previously said "from main `pubspec.yaml`" — wrong; these are
> the LOCAL checkout's files.

Declared in `pubspec.yaml` (local `map_on_home` @ `ec5c5ab`):

- `flutter_map: ^7.0.2`
- `vector_map_tiles: ^8.0.0`
- `vector_tile_renderer: ^5.2.0`
- `mbtiles: ^0.4.2`
- `sqlite3_flutter_libs: ^0.5.41`
- `path_provider: ^2.1.6`, `latlong2: ^0.9.0`, `geolocator: ^14.1.1`,
  `flutter_compass: ^0.8.1`, `http: ^1.2.0`
- Dart SDK constraint: `^3.13.5`

Resolved in `pubspec.lock` (may differ from the caret minimums):
`vector_tile_renderer` 5.2.1, `sqlite3_flutter_libs` 0.5.42, `latlong2`
0.9.1, `http` 1.6.0 (others match their constraints). Remote `origin/map_on_home`
ADDs `maplibre_gl: ^0.27.1` (see "Repository / source of truth").

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
- Format: GeoJSON FeatureCollection — 1,174 `Polygon` + 29 `MultiPolygon`
  geometries (verified 2026-11-11)
- Properties include: `ADM4_EN` (barangay name), `ADM4_PCODE`, `ADM3_EN`
  (city/municipality), `ADM2_PCODE` (`PH07022` = Cebu province),
  `psgc_code`, `psgc_name`, `AREA_SQKM`
- Used by `BarangayRoutePage` for route-aware territory overlay
- **Geometry caveat (verified 2026-11-11):** the file is 1,174 `Polygon` +
  29 `MultiPolygon` features (1,203 total). `BarangayService.load()` only
  accepts `type == 'Polygon'` and **silently skips the 29 MultiPolygons**, so
  the app actually loads **1,174 barangays**, not 1,203. An older revision of
  this file said "Polygon geometries" flat-out — incomplete/wrong.

`assets/cebu.mbtiles` (unused): **REMOVED — the file no longer exists in the
workspace (verified 2026-11-11).** It used to be a raster Esri JPG basemap
(`format=jpg`, z9-15, 5,131 tiles). Historical record only; do not reference
it as present.

## Package behavior (verified 2026-11-11 from local pub cache)

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

## Symptom — HISTORICAL, RESOLVED (was titled "Current symptom")

> Status 2026-11-11: **this bug is fixed and no longer reproduces.** It is kept
> for archaeology only. Current builds bundle `libsqlite3.so` (see "Root cause"
> and "Fix chosen"). Do not treat this as a live issue.

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
  At the time `map_on_home` was still at `4e0c7e63` and lacked that commit.
  **Status now (2026-11-11): superseded** — both branches' `pubspec.yaml`
  contain `sqlite3_flutter_libs: ^0.5.41` (local file verified), so this
  particular gap no longer exists.
- `main` had both the vector map and the sqlite fix, plus a new application id
  (`org.research.seeruta`, app name "SeeRuta"). Installing a build from main
  gives a separate app from the old `com.example.myapp`, so it also avoids any
  stale `<appSupport>/cebu_city.mbtiles` from the old install.
  - **Note:** the 7 main-only commits were overwritten when `main` was
    force-updated to `dac7c83`.

## Fix chosen by the user

Permanently switch the Flutter build workflow to **`main`**:

- `/.github/workflows/flutter.yml` in this workspace was updated to trigger on
  `push`/`pull_request` to `main`. (The job's *display* name still reads
  "Build APK (map_on_home)" — cosmetic leftover; the trigger really is `main`,
  verified 2026-11-11. An older revision of this file claimed the display name
  was "Build APK (main)" — wrong.)
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

## APKs provided to the user (all HISTORICAL — device paths not re-verified)

> **Status 2026-11-11:** these APK paths are on the user's Android device
> (`/storage/emulated/0/Chatcoding/`) and could NOT be re-verified from this
> machine. Newer releases exist than every build listed here (latest:
> `build-beta-6eabffff…` 2026-11-07, and `build-b3bc95a…` for main).
> The "use this one" recommendation below is **superseded** — pull the newest
> release from the GitHub Releases page when a fresh APK is needed.

Former "latest performance build" (now superseded):

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
- A debug APK exists at the same release (`app-debug.apk`,
  200,792,359 bytes ≈ 191.5 MB — verified via `gh release view` 2026-11-11;
  this sentence was previously truncated mid-number in an older revision).

## Workflow run history (append-only log; verified against `gh run list` 2026-11-11)

> Renamed from "In-flight workflow (as of 2026-10-27)" — nothing here is
> in-flight anymore. Two run-ID attributions below were WRONG in the 2026-10-27
> revision and have been corrected: `40543606907` belongs to `3abed2a`
> (success), and `40560462910` belongs to `9abbe6d` (failure).

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
- Push `3abed2a` (telemetry stats wiring) triggered **success** (`40543606907`, 2026-10-27 16:42Z).
- Push `9abbe6d` (tile generation tracking + pinch debounce + adaptive gate pinch mode + debug telemetry) triggered **failure** (`40560462910`, 2026-10-27 18:29Z): `lib/pages/barangay_route_page.dart:163` — `No named parameter with the name 'onTap'` (flutter_map 7 API change), a hard compile error. The same error re-broke `9bf2dd1`'s run (`40618834532`, failure, 2026-10-28 02:05Z) since it was only a docs push. Fixes (wire `MapOptions.onTap`, plain named params, restore `foundation.dart`, fix `_pumpPending()` infinite loop) landed in `ec5c5ab`.
- Push `ec5c5ab` ("fix: resolve flutter_map 7 onTap param in barangay_route_page; fix provider deadlock + stale tile error handling") triggered **success** (`40628837440`, 7m4s) — BETA APK published. This is the last run on `map_on_home` from the local checkout's history.
- Post-2026-10-28 runs (all **success**, BETA workflow, from remote-only commits — local checkout has never seen these):
  - `41204211942` — `79bb031` (merge PR #3, map_gpu_version), 2026-10-31.
  - `42211415013` — `1bdc966` (search-bar re-render fix), 2026-11-06.
  - `42223816983` — `f842d63` (Codespaces build env), 2026-11-06.
  - `42231431100` — `bc1fbb9` (Codespaces part 2), 2026-11-06.
  - `42350168766` — `6eabfff` (Codespaces part 3), 2026-11-07 — latest run.
- Remote `map_on_home` moved to `7de8c7b` ("updating README [skip actions]", 2026-11-07) after those runs; no build needed for that push (`[skip actions]`).
- The `map_gpu_version` branch had its own runs (2026-10-27…10-30): failures `41078555567` (`0b990e6`) and `41081781689` (`e0a4568`), successes on `40685233330`/`40688564747` (`65d22ef`/`8d49f50`), `41076382644`, `41086777116`, `41089580540` (`c98621d`), plus `40625316660` (failure, `34a7e17` maplibre attempt) and `40626402227` (success, `c635405`).

## Verification log (2026-11-11 pass)

Method: every factual claim in this file was checked against the live repo,
GitHub (`gh release list`, `gh run list`, `gh run view`), the local pub cache,
and the installed toolchain. Wrong or stale claims were REPLACED in place
(per the header rules), not appended.

Claims found wrong and replaced:

1. "No local flutter/dart commands can run" — wrong: Flutter SDK is installed
   at `D:\Programs\flutter\bin`; `flutter analyze` runs (0 errors, 4 info lints).
2. "assets = 75.1 MB, 3 files incl. `assets/cebu.mbtiles`" — wrong: that file
   is gone; assets are 2 files / 42,314,058 bytes.
3. Untracked list (`.vscode/`, `lib/CONTEXT.md`, root `main.dart`,
   `launch-opencode-server.vbs`, `logs.zip`…) — wrong: those ARE tracked and
   there is no root `main.dart`; real untracked set recorded instead.
4. "Latest commit `9abbe6d`" — stale (ec5c5ab was already newer locally, and
   the remote has moved to `7de8c7b`); "main is at `b3bc95a`" was true only
   for `origin/main` — local `main` is `5879db6`, diverged (ahead 7 / behind 6).
5. "Latest release `build-5434c65…`" — stale: latest is
   `build-beta-6eabffff…` (beta) / `build-b3bc95a…` (main).
6. `maximumTileSubstitutionDifference: 1` — wrong: code has `0`.
7. `_isPinching` flag — wrong: no such field exists in `lib/`.
8. Job name "Build APK (main)" — wrong: display name is
   "Build APK (map_on_home)" (trigger really is `main`).
9. GeoJSON "Polygon geometries" — incomplete: 1,174 Polygon + 29 MultiPolygon,
   and `BarangayService` loads only the 1,174 Polygons.
10. "Current symptom" — stale: bug is resolved; section marked HISTORICAL.
11. "`map_on_home` lacks sqlite3_flutter_libs" — superseded: both branches have it.
12. Hard rules claiming build files are absent locally — wrong: tracked now.
13. `lib/CONTEXT.md` described as just "tracked" — it's a stale 2026-10-25 copy.
14. Workflow run IDs `40543606907`/`40560462910` swapped between `9abbe6d` and
    `3abed2a` (verified via `gh run view`); corrected, plus 10 newer runs appended.
15. Truncated sentence "A debug APK exists at the same release (200" — completed
    with verified size (200,792,359 bytes).

Claims verified CORRECT (kept as-is): MBTiles metadata (pbf, z0-14, scheme
tms, 6,812 map rows, integrity ok), GeoJSON 1,203 features / ADM2_PH07022,
asset byte sizes for the two remaining files, VectorTileLayer config besides
the substitution value, theme drop-lists, isolate worker/generation/debounce
behavior (100 ms), ProviderException 404 for missing tiles, signing flow via
`android/key.properties` + `seeruta-release.p12`, application id
`org.research.seeruta`, workflow triggers, APK sizes for
`build-4e0c7e63…`, orphaned files (demo_gallery, barangay_map_page,
curved_nav_bar, section_card), nav-bar sides in `main.dart`, Konami/Admin
behavior, `flutter analyze` `continue-on-error` in CI, package versions in
`pubspec.lock`, missing tile tools (tilemaker/tippecanoe/ogr2ogr) and missing
Python geo libs.
