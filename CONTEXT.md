# Project Context: flutter-widget-catalog / SeeRuta offline vector map

Last updated: 2026-11-21 (environment pass: this clone is on a Linux laptop at
`/home/frost/documents/flutter/seeruta` — branch `map_on_home` @ `0f70f31`,
clean tree, in sync with its tracking ref. NEW hard rule from the user: NO
local builds on this laptop — it is too slow; APKs come from the GitHub
Actions workflows. Same day, earlier: map render pass — style tuned for GPU
cost, MapLibre annotation managers cut to line+circle, location source writes
throttled and paused offscreen, MapLibre engine pre-warmed, page widgets
cached across tab slides, Cebu boundary feather moved to a dedicated outline
source; assistant voice commands "where am I" and "scan" wired. 2026-11-20:
startup loading screen (5 s minimum) + camera/mic/location permission
prompts; code-phrase word-spam fix. Hard rule: ALL git write/remote
operations are done ONLY by the user, never by an AI agent.)

## How to read and maintain this file (AI agents, read first)

This file mixes **live facts**, **dated history**, and **opinions**. It WILL
drift. When you read it:

1. **Verify before you act.** Check every claim your task depends on against
   reality, not against this file: `git status -sb`, `git branch -vv`,
   `git log --oneline -5`, `gh release list`, `gh run list`, file sizes,
   `flutter analyze`. Cheap checks beat wrong assumptions. (Git state may be
   stale because agents must NOT fetch/pull — see "Hard rules": only the
   user commits, pushes and pulls — so label remote-state claims with the
   date they were last verified by the user.)
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

- **The user performs every git operation that writes or syncs history.**
  Do NOT run `git commit`, `git push`, `git pull`, `git fetch`,
  `git merge`, `git rebase`, `git reset`, `git stash`, `git cherry-pick`,
  `git revert`, `git tag`, or `git branch` (create/delete/rename) — and do
  not use `gh` to publish releases, dispatch workflows, or edit remote
  state. (Confirmed by the user 2026-11-20.) Read-only git commands are
  fine for verification: `git status`, `git status -sb`, `git log`,
  `git branch -vv`, `git diff`, `git show`, `git remote -v`.
  Workflow: make the code edits, report exactly which files changed and
  what the change does, then hand off — the user commits, pushes and
  pulls.
- **Do not guess.** Ask clarifying questions (use the `question` tool) before
  making assumptions that change behavior.
- Keep edits scoped: the user primarily edits `lib/` and `assets/`. The
  build files (`pubspec.yaml`, `analysis_options.yaml`, `android/`, `.github/`)
  ARE present and tracked in this clone (verified 2026-11-11) — do not delete
  or "restore" them; only touch them when the task requires it (e.g. adding a
  dependency or asset declaration).
- **NO local builds on this Linux laptop** (user instruction 2026-11-21 — too
  slow; "we have github actions for this reason"). APKs come from the GitHub
  Actions workflows (`.github/workflows/`: `flutter.yml` → `main`,
  `flutter_beta.yml` → `map_on_home`, `build-mbtiles.yml` → manual
  `workflow_dispatch`). Never run `flutter build` / `flutter run` / gradle
  here. Lightweight verification (`flutter analyze`, `flutter test`) is still
  allowed — a Flutter SDK exists at `/home/frost/flutter/bin/flutter`
  (verified 2026-11-21) — but keep it minimal because the machine is slow.
  The old `D:\Programs\flutter\bin\flutter.bat` SDK claim (verified
  2026-11-11) belonged to the Windows clone, a different machine.
- Historical note: an older instruction said "workspace = lib/ + assets/ only,
  do not restore build files" — that described a period when those files were
  absent from the clone. It is no longer true; build files are tracked now.
- Leave these extras alone (do not clone/copy them into the workspace):
  `.and-code/`, `ENVIRONMENT_CAPABILITIES.md`, `google-cloud-cli-linux-arm.tar.gz`,
  `google-cloud-sdk/`. None of them exist in the workspace as of 2026-11-11 —
  keep it that way.

## Repository / source of truth

- Remote: https://github.com/FilipinoCollabEmtech/flutter-widget-catalog.git
- **CURRENT workspace (this clone, verified 2026-11-21):**
  `/home/frost/documents/flutter/seeruta` (Linux laptop; IS a git clone, has
  `.git/`). The Windows path `C:\Users\Adminator\Documents\SeeRuta\teammate`
  is a DIFFERENT clone on another machine — claims written for it may not
  apply here.
- **Branch state of this clone (verified 2026-11-21, no fetch run):**
  - Checked out: `map_on_home` @ `0f70f31` ("feature: when users say scan, it
    now opens the camera page. When users say Where am I, it shows their
    location."), clean working tree, matching its `origin/map_on_home`
    tracking ref. The 2026-11-20 claim of `43c0f5c` is superseded.
  - Local `main` = `b3bc95a`, in sync with `origin/main` — NOT the diverged
    `5879db6` the old Windows clone had (that claim is superseded).
  - Also present: local branch `fix-barangay-naming-highlight` @ `e0afbea`,
    in sync with its origin.
  - Windows-clone branch state as of 2026-11-11 (history only, remote refs
    have moved since): local `map_on_home` = `1ab13e0`, local `main` =
    `5879db6` diverged ahead 7 / behind 6 vs `origin/main`.
  - Also on remote: `origin/map_gpu_version` = `c98621d` (merged into
    `map_on_home` via PR #3, 2026-10-31).
- What the 14 commits changed (map_on_home): MapLibre migration
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
  A third workflow `flutter_beta_gpu.yml` publishes
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
  - Admin page: live telemetry (renderer, style, max zoom, glyphs), app info,
    debug switches (rebuild map style, refresh stats), layer visibility toggles
    that actually control MapLibre layers (vector tiles, Cebu boundary, direction
    arrow, user location, route polyline, barangay polygons/labels).
  - HomePage: passes layer-visibility ValueNotifiers to CebuMapView, which uses
    `setLayerVisibility` to show/hide MapLibre layers. Admin "Rebuild map style"
    bumps a ValueNotifier that HomePage listens to, re-calling OfflineMapAssets.prepare().
    NOT on `main` yet (main is for final fixed versions)
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

## Current workspace state (verified 2026-11-21, Linux laptop clone)

- Checked-out branch: `map_on_home` @ `0f70f31` ("feature: when users say
  scan, it now opens the camera page. When users say Where am I, it shows
  their location."), clean working tree, matching the `origin/map_on_home`
  tracking ref (no fetch/pull run). The 2026-11-20 claim of `43c0f5c` is
  superseded; the 2026-11-20 uncommitted file list below no longer applies —
  the user committed that work (`43c0f5c`) plus the map render pass
  (`fee9962` "optimizing map speed", `2742327` "fix: that random line when
  zoom level < 9.0 on the south of Naga", `0f70f31`).
- Local output dir `build/` exists but is git-ignored (leftover local build
  output; harmless, not tracked).
- Tracked dirs beyond the inventory below (this clone, verified 2026-11-21):
  `ios/`, `linux/`, `macos/`, `web/`, `windows/`, `tools/`, `tool/` plus
  root helpers `_iconsearch.py`, `build_exe_executable.ipynb`,
  `google_colab_connection.ipynb`, `seeruta_download_page.html`.
- The file inventory below was verified 2026-11-18 and is retained as a
  dated snapshot, not a current list.
- `lib/` (24 Dart files):
  - App shell: `main.dart`
  - `pages/`: `home_page.dart`, `mbtiles_vector_tile_provider.dart`,
    `adaptive_tile_gate.dart`, `admin_page.dart`, `cebu_boundary_layer.dart`,
    `cebu_map_view.dart`, `cebu_style.dart`, `camera_demo_page.dart`,
    `barangay_route_page.dart`, `animated_map_mover.dart`, `location_service.dart`,
    `user_location_layer.dart`, `offline_map_assets.dart`, `profile_page.dart`
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
    exists**; only the two files above are present.
    A 0-byte `cebu_city.mbtiles` was tracked at the repo ROOT as an empty
    placeholder but is **not present** in this workspace or on remote as of
    2026-11-11 (the real asset is `assets/maps/cebu_city.mbtiles`).
- Root extras (tracked): `CONTEXT.md`, `Features.md`, `README.md`,
  `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `start-opencode-server.bat`,
  `workflow_logs.txt`, `logs.zip`, `logs_clean.zip`, `.vscode/launch.json`,
  `lib/CONTEXT.md`. (An older revision listed these as untracked and listed a
  root `main.dart` — there is NO root `main.dart` and these ARE tracked.)
- `.github/workflows/`: `flutter.yml` (push/PR → `main`), `flutter_beta.yml`
  (push/PR → `map_on_home`), `flutter_beta_gpu.yml` (GPU build), `build-mbtiles.yml`
  (manual `workflow_dispatch`).
- **Local tools (Windows clone, verified 2026-11-11 — historical; see the
  Hard rules bullet for this laptop's tools):**
  - `flutter` / `dart` ARE installed on the Windows clone:
    `D:\Programs\flutter\bin\flutter.bat` (an older revision claimed no
    Flutter SDK — wrong now). `flutter analyze` ran there: **0 errors, 2
    info-level lints** in `lib/pages/cebu_map_view.dart:214` and
    `lib/pages/cebu_style.dart:60` (both `use_null_aware_elements`).
    `flutter analyze` exits non-zero on info lints even though CI ignores it
    (`continue-on-error: true`).
  - On the Windows clone: `gh` installed and authenticated; `python` 3.14.6.
    NOT installed there: `tilemaker`, `tippecanoe`, `ogr2ogr`. Python geo
    libs NOT installed: `mapbox_vector_tile`, `osmium`, `shapely`,
    `mercantile`, `pmtiles`, `pyproj` (all verified `find_spec == None`).
    On this Linux laptop these have NOT been re-verified (2026-11-21).
  - MBTiles/GeoJSON verification scripts from the 2026-11-11 pass live on the
    Windows machine in `%TEMP%\opencode\verify_context.py`, `verify_geo2.py`,
    `verify_mb3.py`, `lockver.py` (outside the workspace).

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

Map rendering (MapLibre, current):

- Home's map is `CebuMapView` → `ml.MapLibreMap` (native GPU view). The style
  JSON written by `OfflineMapAssets.prepare()` comes from
  `buildCebuLightStyle()` in `lib/pages/cebu_style.dart`: 25 layers over the
  OpenMapTiles schema, `mbtiles://` source on the copied
  `assets/maps/cebu_city.mbtiles`, glyphs from `assets/glyphs/`.
- Render-time settings (verified 2026-11-21): the vector source declares
  `maxzoom: 14` (data unchanged — above z14 MapLibre overzooms those tiles
  instead of requesting z15+ tiles that do not exist); `fill-antialias: false`
  on landcover, landuse, park, water and `aeroway_area` (they are broad flat
  fills, so the second AA geometry pass was invisible); place labels no longer
  use `text-halo-blur` (keeps the 1.5 px halo).
- The Home map registers only `line` + `circle` annotation managers
  (`annotationOrder` / `annotationConsumeTapEvents`); it only ever adds a
  route line and two endpoint circles. `barangay_route_page.dart` still needs
  all four types and keeps the default.
- The grey Cebu mask is two sources in `cebu_map_view.dart`:
  `cebu-mask` (world polygon with the outline as a hole, fill only) and
  `cebu-outline` (the same rounded outline as a LineString) for the 28 px
  blurred feather line. The feather must not live on the polygon source:
  geojson-vt clips the world polygon per tile and closes its rings along the
  tile borders, so a line layer there stroked those borders as long straight
  grey bands across Cebu (visible below z9, e.g. through/south of Naga).
- User-location GeoJSON writes are throttled to 100 ms, deduplicated against
  the last pushed fix, and skipped while the Admin "user location" toggle is
  off or while the Home page is parked offscreen (the shell disables its
  `TickerMode`); the latest fix is pushed when either comes back.
- `main()` calls `MapLibreMap.preWarm()` so the native engine loads during
  app start. `_HomeScreenState` caches page widgets (`_pageWidgets`, dropped
  when a page is dropped or Admin replaces Profile) so a tab slide moves the
  existing page layers instead of rebuilding the map page every transition
  frame.

Map style (HISTORICAL — flutter_map era, changed 2026-10-25, commit `dac7c83`;
superseded by the MapLibre style above):

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
- **Status: dead code** — the app now uses MapLibre (native GPU rendering) via
  `CebuMapView`, not `vector_map_tiles` + `MbtilesVectorTileProvider`. The class
  remains in the tree but is not imported by any active page. `admin_page.dart`
  previously imported it for `debugTelemetry`; that reference was removed when
  the Admin panel was reworked for MapLibre.

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

## Dependency versions (verified 2026-11-18, branch `map_on_home` @ `a9041ea`;
SeeRuta whisper patch added 2026-11-20, HEAD `43c0f5c`)

Declared in `pubspec.yaml`:

- `flutter_map: ^7.0.2`, `latlong2: ^0.9.0`, `geolocator: ^14.1.1`,
  `cupertino_icons: ^1.0.8`, `path_provider: ^2.1.6`, `flutter_compass: ^0.8.1`
- `vector_map_tiles: ^8.0.0`, `vector_tile_renderer: ^5.2.0`, `mbtiles: ^0.4.2`
- `http: ^1.2.0`, `sqlite3_flutter_libs: ^0.5.41`, `maplibre_gl: ^0.27.1`
- `sqlite3: ^2.9.4`, `google_mlkit_text_recognition: ^1.0.3`, `camera: ^0.12.2`,
  `flutter_onnxruntime: ^1.9.0`
- `shared_preferences: ^2.5.0` (2026-11-18 — persists the SeeRuta
  Assistant toggle; resolved **2.5.6**)
- `whisper_ggml: ^2.10.0` (NEW 2026-11-18 — offline ASR, whisper.cpp core;
  resolved **2.10.0**; transitive `ffmpeg_kit_flutter_new_min` 2.1.0).
  **2026-11-20:** overridden to the vendored path
  `third_party/whisper_ggml` (same 2.10.0 plus the native latency patch);
  `pubspec.lock` source is now `path`.
- `record: ^7.0.0` (NEW 2026-11-18 — mic capture; resolved **7.2.0**)
- `flutter_tts: ^4.2.5` (NEW 2026-11-18 — spoken feedback; resolved **4.2.5**)
- Asset added 2026-11-18: `assets/models/whisper/ggml-tiny-q5_1.bin`
  (32,152,673 bytes, bundled whisper model; pubspec entry added because
  Flutter asset dirs are non-recursive, so `assets/models/` does not cover
  the subfolder).
- Dart SDK constraint: `^3.13.5`; package `name: seeruta`

Older resolutions (`vector_tile_renderer` 5.2.1, `sqlite3_flutter_libs`
0.5.42, `latlong2` 0.9.1, `http` 1.6.0) recorded on 2026-11-11; not all
re-checked on 2026-11-18 (`flutter pub get` ran clean).

Settings feature (added 2026-11-18 on this branch): `lib/pages/settings_page.dart`
— Accessibility section with the SeeRuta Assistant toggle (persisted via
`shared_preferences`, key `AssistantService.assistantPrefKey` =
`seeRutaAssistantEnabled`). On toggle it now speaks a confirmation through
`flutter_tts` (audio-first) plus a SnackBar; Home reads the same key to show
or hide the mic button.

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
16. "`map_on_home` local = `ec5c5ab`, 14 behind remote" — wrong: local is now
    `1ab13e0`, up to date with `origin/map_on_home` (pulled remote commits
    including MapLibre files `cebu_map_view.dart`, `cebu_style.dart`,
    `offline_map_assets.dart`).
17. Root `cebu_city.mbtiles` 0-byte placeholder exists (tracked) — wrong: file
    is not present in this workspace or on remote as of 2026-11-11.
18. `flutter analyze`: 4 info lints in `mbtiles_vector_tile_provider.dart` —
    wrong: now 2 info lints (`use_null_aware_elements`) in `cebu_map_view.dart:214`
    and `cebu_style.dart:60`.
19. `maplibre_gl: ^0.27.1` declared only on remote — wrong: now declared in
    local `pubspec.yaml` too.
20. `flutter_beta_gpu.yml` is remote-only — wrong: it exists locally as well.
21. `lib/` has 21 Dart files and omits MapLibre pages — wrong: 24 Dart files;
    `cebu_map_view.dart`, `cebu_style.dart`, `offline_map_assets.dart` are present.
22. Admin page imports `mbtiles_vector_tile_provider.dart` and references
    `MbtilesVectorTileProvider.debugTelemetry` — wrong: that provider is dead
    code under MapLibre; the import and the `debugTelemetry` switch were removed
    from `admin_page.dart`.
23. Admin layer toggles don't control anything — wrong: `showCebuBoundary`,
    `showUserLocation`, `showCebuArrow`, `showVectorTiles` now flow from
    `main.dart` → `HomePage` → `CebuMapView`, which calls MapLibre's
    `setLayerVisibility` to show/hide the corresponding layers.
24. Admin "Force tile reload" / "Refresh stats" are stubs — wrong: replaced with
    "Rebuild map style" (bumps `rebuildStyleKey`, HomePage re-calls
    `OfflineMapAssets.prepare()`) and "Refresh stats" (recomputes `debugStats`).
25. Admin telemetry references tile-gate/concurrency stats — wrong: now shows
    MapLibre-relevant info (Renderer, Style, Max zoom, Glyphs).

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

## Verification log (2026-11-18 pass — settings feature on map_on_home)

Context: the Settings feature (settings page + SeeRuta Assistant toggle +
burger-menu wiring + `shared_preferences`) had been added on the
`fix-barangay-naming-highlight` branch (commit `35abcb9`, 2026-11-18); the
user then switched to `map_on_home` @ `a9041ea`, where it was absent, and
asked to re-add it.

Checked 2026-11-18 (read-only + code edits; NO git pull/push/commit, NO
flutter build):

- `map_on_home` checked out @ `a9041ea`, in sync with its origin (per
  `git status -sb`); `settings_page.dart` absent, `shared_preferences`
  absent from `pubspec.yaml` — both re-added.
- This branch's `pubspec.yaml` additionally declares
  `flutter_onnxruntime: ^1.9.0` (not present on the other branch).
- Burger menu on this branch has the same shape (`_buildMenuPanel`,
  `_menuTile`, `_example('Settings')` placeholder in `home_page.dart`
  ~line 448) — wired the same way as before (push `SettingsPage`).
- `flutter pub get` ran (resolved `shared_preferences` 2.5.6;
  pubspec.lock + plugin registrants refreshed as a side effect).
- `flutter analyze`: no new `lib/` issues (same two pre-existing
  `use_null_aware_elements` info lints: `cebu_map_view.dart:282`,
  `cebu_style.dart:60`).
- User will commit/push; builds happen via workflow as usual.

## SeeRuta Assistant — locked design (2026-11-18)

Decisions confirmed by the user in a design discussion on 2026-11-18 (no
Assistant behavior shipped yet beyond Phase 0 below):

- **Languages:** English + Filipino + Cebuano. Output must be audible
  through the speaker.
- **Fully offline is a research requirement.** Platform speech services are
  NOT relied on (Android's recognizer is only offline when the user happened
  to pre-download language packs).
- **Wake word:** openWakeWord "SeeRuta" models run via
  `flutter_onnxruntime` (already in pubspec and already used by
  `ppocr_ocr.dart`, so the native runtime cost is already in the APK);
  ~4 MB of ONNX models. Alternative rejected: `porcupine_flutter` (fast to
  train but requires an AccessKey and free-tier limits unsuited to a
  publicly distributed app).
- **ASR (changed 2026-11-18, verified against real model sizes):**
  `whisper_ggml` ^2.10.0 (whisper.cpp v1.9.5 core, MIT) with the bundled
  `ggml-tiny-q5_1.bin` (~31 MB, md5 531c3bec8666a67ed7f0c0779c58fd61,
  multilingual) copied once from assets to the app-support dir. Decoding
  runs in **English mode** (`lang: 'en'`) — faster and deterministic, and
  whisper has no Cebuano token; Cebuano commands ride the parser tables.
  `sherpa_onnx` was chosen in the design discussion but REJECTED after
  measuring: its whisper-tiny int8 split is encoder 12.9 MB + decoder
  89.9 MB = **103 MB** — 3x the size of Q5-whisper.cpp for the same weights.
  `flutter_whisper` was also rejected: it can only download models from
  HuggingFace (no `modelPath:` for a bundled asset), which breaks the
  zero-setup decision. whisper_ggml API facts (verified from the pub cache):
  `transcribe()` accepts only the model enum (download path); bundled models
  go through `transcribeLive(modelPath: ...)`, which takes a 16 kHz mono
  PCM16 stream, `initialPrompt` vocabulary biasing, and
  `suppressNonSpeechTokens`; `WhisperLiveSession.stop()` is idempotent;
  Silero VAD (`vadModelPath`) applies to `transcribe()` only, so live
  sessions rely on its built-in energy gate. **2026-11-20:** the package is
  vendored at `third_party/whisper_ggml` with a native encoder-window /
  no-fallback patch (see pass 5 log); the app opens the gate and feeds one
  finished utterance once. Transitive dep cost:
  `ffmpeg_kit_flutter_new_min` 2.1.0 (unavoidable). Android minSdk = 24 =
  Flutter 3.47 default (no gradle change). Upgrade path if field tests
  disappoint: `ggml-base-q5_1.bin` (~57 MB), same code change.
- **Languages (updated 2026-11-19, user instruction):** recognition scope is
  **English + Cebuano**; **Tagalog removed** ("remove the Tagalog features
  and use English and Cebuano"). Whisper has no `ceb` token, so decoding
  runs with `lang: 'en'` (also faster than `'auto'`) and Cebuano commands
  are absorbed by the parser's Cebuano word tables. Spoken responses remain
  English for now. A Cebuano fine-tune of the bundled whisper model with
  recorded commands remains a later-phase option.
- **Output (v1):** `flutter_tts` ^4.2.5 platform voices, English responses,
  speech rate 0.55 (`AssistantService.speechRate`) with
  `awaitSpeakCompletion(true)` so spoken feedback never overlaps. The
  pre-recorded Cebuano template idea (`audioplayers`) moves with the
  deferred Cebuano phase.
- **Understanding:** NO model — `lib/services/assistant_command_parser.dart`
  (Phase 0, pure Dart): digit/letter word tables (en/fil/ceb plus
  Spanish-derived forms used in Cebu street speech), tens composition
  ("twenty four" -> 24, "napulo ug usa" -> 11), wake-variant stripping,
  filler stripping, and OSA (Damerau-Levenshtein) fuzzy matching within one
  edit against the 35 real codes with tie-breaks
  (distance -> prefix-extension -> letter-shape -> substring -> lexical).
- **Blind-first UX requirements (to implement in later phases):** spoken +
  haptic confirmation for every state change; earcon on wake; backup
  triggers (media/headset button, "Talk" button on a persistent
  notification, hold-to-talk) because wake words fail in street noise;
  TalkBack coexistence; never leave the user in silence (timeout prompt);
  "repeat" command; barge-in.
- **Dependency status (updated 2026-11-18):** `whisper_ggml` ^2.10.0,
  `record` ^7.0.0 (resolved 7.2.0), `flutter_tts` ^4.2.5 are NOW ADDED and
  in use. `audioplayers` stays out until the deferred Cebuano template
  phase. Still NOT adding: `speech_to_text`, `porcupine_flutter`,
  `vosk_flutter`, `sherpa_onnx` (103 MB model tax), `flutter_whisper`
  (download-only), any LLM package.
- **Manifest (DONE 2026-11-18):** `RECORD_AUDIO` added to
  `android/app/src/main/AndroidManifest.xml`. The foreground-service
  backup triggers (Talk notification button, media/headset button) remain a
  later phase — v1 capture is driven by the Home mic button only.
- **Phase plan (updated 2026-11-19):** 0 command parser + tests (DONE);
  1 TTS + permission + mic-button wiring, voice recognition end to end
  (DONE, committed by user); 1b language switch + speed pass (DONE
  2026-11-19: English + Cebuano, `lang: 'en'`, background model warm-up,
  silence auto-stop) and the same-day capture fix (DONE, UNCOMMITTED:
  buffered capture, DC-corrected fixed-floor auto-stop, one gate-free decode
  of the finished utterance with speech-region trim, mic diagnostics in
  Admin); 2 wake-word runtime ("SeeRuta" via openWakeWord on
  flutter_onnxruntime) + one-time Colab training of the custom model;
  3 field tuning with PWD users (auto-stop threshold, speech-trim floor,
  prompt wording) and CI APK slimming (`--split-per-abi` so the
  fat APK's native libs don't 4x); 4 (optional) Cebuano recordings +
  whisper fine-tune + Cebuano TTS templates.

Phase 0 files: `lib/services/assistant_command_parser.dart`,
`test/assistant_command_parser_test.dart` — `flutter test
test/assistant_command_parser_test.dart`: **28/28 pass (2026-11-19)**;
`flutter analyze` still reports only the 2 pre-existing info lints.

Phase 1 files (committed by the user 2026-11-18 as `1128c13`):
`lib/services/assistant_service.dart` (new voice pipeline: model copy from
assets, `record` 16 kHz PCM16 stream -> `transcribeLive`, parser, TTS),
`lib/pages/home_page.dart` (mic button between SearchBar and burger, shown
only when the Settings toggle is on; capture start/stop with 8 s cap;
commands: findRoute + help/repeat/stop wired, whereAmI (= locate button
path: enable GPS, centre on the fix) and scan (= `RouteFocus.openScanner()`,
slides to the camera tab) wired, nearest/fare still speak "coming soon"),
`lib/pages/settings_page.dart` (shared pref key, TTS
confirmations), `android/app/src/main/AndroidManifest.xml` (`RECORD_AUDIO`),
`pubspec.yaml` (3 deps + model asset), `assets/models/whisper/
ggml-tiny-q5_1.bin` (new 31 MB bundled model).

Phase 1b speed + language pass (2026-11-19, committed as `b3a1791`):
`assistant_command_parser.dart` + `test/assistant_command_parser_test.dart`
(Tagalog tables/keywords removed, Cebuano strengthened with `hain`,
`napulog`, native tens `katloan`..`kasiyaman`, `plite`; tests 28/28),
`assistant_service.dart` (`lang: 'en'` instead of `'auto'`, trimmed
English+Cebuano prompt, `warmUp()` parks the model in native memory),
`home_page.dart` (background warm-up when the toggle is on; "Listening" TTS
removed so the mic does not record the speaker), `settings_page.dart`
(subtitle names English + Cebuano). Admin transcript log added the same day
(`563f865`): `lib/services/voice_log.dart` (new; newest-first, max 100,
persisted in shared_preferences key `seeRutaVoiceLog`, corrupt lines
skipped), `test/voice_log_test.dart`, `admin_page.dart` (new "Voice
Recognition" section between Live telemetry and Researcher tools: live
transcript list with timestamps + Clear). CI history: the first voice build
failed on unaccepted NDK 29 licenses; fixed by user commits `bd28314`
(license step) and `5c10410` (reload Assistant pref on return from Settings);
build `44261603975` succeeded 2026-11-18.

## Verification log (2026-11-18 pass — SeeRuta Assistant voice recognition, Phase 1)

- Decision change, verified by measuring the actual model files: ASR package
  switched from `sherpa_onnx` (whisper-tiny int8 = encoder 12.9 MB + decoder
  89.9 MB = **103 MB**, too big vs the "most size-efficient" requirement) to
  `whisper_ggml` ^2.10.0 (whisper.cpp v1.9.5, MIT) with bundled
  `ggml-tiny-q5_1.bin` = **32,152,673 bytes (~31 MB)**, md5
  `531c3bec8666a67ed7f0c0779c58fd61` (HuggingFace `ggerganov/whisper.cpp`).
  The Silero VAD model was downloaded then deleted: it only works with
  `transcribe()`, which cannot take a bundled path, and live sessions have
  their own energy gate.
- `flutter pub get` clean: whisper_ggml 2.10.0, record 7.2.0, flutter_tts
  4.2.5 (+ transitive ffmpeg_kit_flutter_new_min 2.1.0). Package API facts
  verified from the local pub cache before writing code (transcribeLive
  signature, WhisperLiveSession.partials/stop idempotency, record 7
  startStream/hasPermission/dispose).
- `flutter analyze`: only the 2 pre-existing `use_null_aware_elements` info
  lints (`lib/pages/cebu_map_view.dart:282`, `lib/pages/cebu_style.dart:60`).
- `flutter test test/assistant_command_parser_test.dart`: 26/26 pass.
- NOT verified on a device yet (no local build allowed; APKs come from the
  teammate's GitHub Actions): actual recognition quality of tiny-q5_1 on
  Tagalog/English street audio, the energy gate defaults in noise, and the
  APK size delta (expect ~31 MB asset + ffmpeg/whisper native libs).
  Next real-world check: install the next CI APK, toggle the Assistant in
  Settings > Accessibility, use the Home mic button, say e.g. "code zero
  four L".
- Cleanup note: `/tmp/opencode/whisper-tiny.tar.bz2` (116 MB, sherpa model
  tarball) is obsolete and can be deleted.

## Verification log (2026-11-19 pass — English + Cebuano, speed optimizations)

- User reported slow recognition and asked to drop Tagalog in favor of
  English + Cebuano. Parser tables edited: removed Tagalog-only entries
  (`isa`, `dalawa`, `tatlo`, `apat`, `anim`, `sampu`/`sampo`,
  `dalawampu`/`dalawamput`, `at` connective, `ulit`/`ulitin`/`ulita`,
  `hinto`/`ihinto`, `tulong`/`tulungan`, `magkano`, `nasaan ako`,
  `malapit`/`malapitan`, `kalayo`, fillers `lang`/`paki`/`ung`/`yung`).
  Added Cebuano: `hain ko`/`hain ako` where-phrases, `napulog` (contracted
  11+), native tens `katloan`, `kapatan`, `kaliman`, `kanuman`,
  `kapitoan`, `kawaloan`, `kasiyaman`, `plite`/`plete` fare words, `tabangi`,
  `usba`, `undangi`, `hunonga`, `palihug`.
- Speed changes in `assistant_service.dart`/`home_page.dart`:
  `lang: 'en'` instead of `'auto'` (no language-detection pass; deterministic
  decode); prompt trimmed to English + Cebuano command words; `warmUp()`
  loads and parks the model in native memory as soon as the Settings toggle
  is on (Home calls it in the background); Dart RMS watcher on the PCM16
  stream auto-stops capture ~0.8 s after speech ends (5 s no-speech
  timeout, 0.25 s voiced arming) so no second tap is needed; the "Listening"
  TTS announcement was removed because the mic would record it (haptic
  feedback remains). The 8 s safety cap stays.
- `flutter analyze`: only the 2 pre-existing `use_null_aware_elements` info
  lints. `flutter test test/assistant_command_parser_test.dart`: **28/28
  pass** (4 new Cebuano cases; Tagalog assertions removed).
- NOT device-verified: perceived latency of the new flow (first tap after
  warm-up should skip model load; decode of a typical 2-second utterance
  with tiny-q5_1 is expected to be sub-second to ~2 s on a low-end phone),
  and auto-stop thresholds in loud street noise. Tune `_autoStopSilence`,
  `_gateVoiceRatio`, `_gateRmsMin` from field reports. If Cebuano
  recognition proves too weak with an English-mode multilingual model, the
  documented upgrade path is `ggml-base-q5_1.bin` (~57 MB, one-line swap)
  or a later fine-tune.

## Verification log (2026-11-19 pass 2 — Admin > Voice Recognition)

- New `lib/services/voice_log.dart`: `VoiceLog.instance` keeps the final
  transcripts from `AssistantService.stopCapture()` newest-first, capped at
  100 entries, persisted as JSON strings in shared_preferences under
  `seeRutaVoiceLog`. Nothing leaves the device; the Admin page has a Clear
  action. Logging is fire-and-forget so it never delays the spoken answer.
  (Superseded the same day by pass 3: entries now also carry capture
  diagnostics, and empty captures are logged.)

- The 0.8 s RMS auto-stop described in the 2026-11-19 pass above was
  superseded later the same day by `voice_activity.dart`; see pass 3 below.
- `lib/pages/admin_page.dart`: new section "Voice Recognition" between Live
  telemetry and Researcher tools. Live `ValueListenableBuilder` list (mic
  icon, transcript text, `YYYY-MM-DD HH:MM:SS` timestamp), empty state
  explaining how to produce transcripts, Clear button. `ensureLoaded()` is
  called in `initState`.
- Checks: `flutter analyze` still reports only the 2 pre-existing info
  lints; `flutter test test/voice_log_test.dart
  test/assistant_command_parser_test.dart` = **33/33 pass** (5 new voice-log
  tests: newest-first, persistence across instances, clear, 100-entry cap,
  corrupt-line skipping). Not device-verified (admin UI is only reachable
  after the Konami unlock).

## Verification log (2026-11-19 pass 3 — silent-capture fix)

- User report: the Assistant could not hear anything at all, even speaking
  loudly and clearly in a quiet room, and Admin > Voice Recognition stayed
  empty; recognition must also work in dense, loud streets. Two ways the
  pipeline could silently return nothing were found by reading the code
  (`record` 7.2.0 and `whisper_ggml` 2.10.0 sources in the pub cache):
  1. **Audio was dropped before the decoder listened.** `record` pumps its
     platform stream into a broadcast controller and only forwards chunks
     when the controller has a listener. `AssistantService` opened the mic
     first, then `transcribeLive` awaited `startWhisperLiveSession` (model
     load/borrow) before attaching its listener. On a cold model that is
     seconds of speech thrown away; the final transcript is empty.
  2. **Auto-stop could fire on room tone, before speech.** The Dart watcher
     scaled its threshold by an adaptive noise floor (`max(2.5 * floor,
     0.0015)`). Loud ambient or a DC-biased ADC crossed it, armed
     `_heardSpeech`, and stopped 0.8 s later — often before the user spoke.
     In the reverse case a quiet mic never armed the watcher and the native
     live gate (ratio-based too) also marked the audio unvoiced, so the
     decoder emitted nothing.
- Fix, `lib/services/assistant_service.dart` (live-pass design **superseded
  by pass 4** below; kept as history): the live decoder session was started
  **first**, then the mic, and chunks were fed explicitly with
  `WhisperLiveSession.feed` — no window where the recorder had audio and
  the decoder had no listener. Every chunk was buffered (max 15 s); if the
  live pass returned empty but the mic delivered audio (peak >= 0.003,
  >= 0.5 s), the whole buffer was decoded again by a second session with
  `gateRmsMin: 0, gateVoiceRatio: 0` (open gate). The parked model was
  borrowed for that retry, so it cost one decode, not a model load. Live
  gate retuned to `gateRmsMin: 0.002`, `gateVoiceRatio: 1.5`,
  `gateNoiseFloorCap: 0.01`. Recorder now uses
  `AndroidAudioSource.voiceRecognition` (ASR-tuned, no `DEFAULT`
  device-to-device processing) and `AudioRouteChangeMode.follow` (all still
  current).
- New `lib/services/voice_activity.dart` (`VoiceActivityDetector`):
  **DC-removed** RMS (a constant ADC bias is not speech) with a speech
  floor calibrated from the quietest chunk in the first 0.3 s (settle
  window, also skips the tap transient), allowed to rise only to
  `max(0.006, min(1.6 * ambient, 0.012))` and frozen after calibration, so
  traffic noise cannot lift it above a soft speaker and a long utterance
  cannot raise its own threshold. 0.45 s voiced audio arms the stop, **0.8 s
  of silence ends it (pass 5; was 1.2 s)**, and 10 s without speech times
  out. Loud steady noise never accumulates silence, so the pass-3 design
  could only stop at the caller's cap; **pass 5 adds a 7.5 s speech cap**
  (`maxSpeechSeconds`), leaving the 12 s `AssistantService.maxCapture` as
  an absolute fallback. Auto-stop is a convenience in quiet rooms, never a
  gatekeeper.
- `lib/services/voice_log.dart`: entries now carry `VoiceCaptureStats`
  (seconds, DC-corrected peak RMS, voiced seconds, chunk count, retried,
  silence tail, decoder milliseconds, legacy last partial, error).
  **Every finished capture is logged**, including
  ones that heard nothing and start failures; load sorts newest-first and
  still accepts legacy `{t,x}` lines. Admin > Voice Recognition shows
  "Nothing recognized" entries with `duration · voiced · peak% ·
  full-buffer decode` and errors. (Pass 4 removed the live-partial line;
  the `partial` field now only appears in older persisted entries.)
- Checks: `flutter analyze` = only the 2 pre-existing info lints;
  `flutter test test/assistant_command_parser_test.dart
  test/voice_log_test.dart test/voice_activity_test.dart` = **43/43 pass**
  (28 parser + 7 voice-log + 8 voice-activity). Tests cover quiet room
  tone, steady loud noise (must not auto-stop), speech-then-silence, soft
  speaker calibration, no-speech timeout, tap transient, DC offset,
  odd-offset PCM, persistence, newest-first ordering, and empty-capture
  logging.
- NOT device-verified. Next check: install the next CI APK, tap the Home
  mic, say "code zero four L" in a quiet room and again on a loud street,
  then read Admin > Voice Recognition. How to read the entry:
  `0 chunks / No audio` = mic/permission/device path; `chunks > 0` but
  `peak` below ~1% = mic gain or OS processing; high `peak` with `0.0 s
  voiced` = speech detector floor; `full-buffer decode` = the live gate
  missed it and the fallback recovered (or also failed) the transcript;
  `Heard "..." before the final pass` = partials worked but finalization
  did not.

## Verification log (2026-11-19 pass 4 — one-shot decode)

- User report after pass 3: "help" was recognized, but longer phrases were
  not. Admin showed e.g. `10.5 s · 4.2 s voiced · peak 16.8% · full-buffer
  decode`, `Heard " p" before the final pass`, and `Error:
  TimeoutException after 0:00:30`; a "scan" capture reached the partial
  ` scan.` and then timed out the same way. The mic, the speech detector and
  whisper itself were therefore working — only finalization never returned.
- Root cause: the live pass is **O(n²)** in the utterance length.
  `whisper_ggml` 2.10.0 re-decodes the whole growing window each time 1.5 s
  of new voiced audio has arrived. A 10.5 s phrase is decoded as windows of
  1.5, 3.0, ... 10.5 s — ~40 s of audio of inference — and `stream_feed`
  runs that synchronously inside the worker isolate, so the caller's `stop`
  message queued behind the backlog. The 30 s `stop()` timeout then expired
  with `last_text` empty. "help" is shorter than 1.5 s, so it never
  triggered a mid-capture decode and its single tail decode worked: exactly
  the reported pattern. The old fallback then started a *second* live
  session while the first was still inside the native global `g_stream`,
  which the package documents as one-session-at-a-time; that is why the
  retry also timed out and the entry stayed empty.
- Fix: no streaming decode. `AssistantService.startCapture` only opens the
  recorder and buffers PCM; `VoiceActivityDetector` still owns auto-stop and
  now also reports the speech sample range. `stopCapture` prepares the clip
  and decodes it **once** with `startWhisperLiveSession(gateRmsMin: 0,
  gateVoiceRatio: 0)`: a single `feed` makes the first (and only) inference
  pass over the whole clip and `stop` returns it — linear, not quadratic.
  The model is borrowed from the warm-up park; timeout 45 s. If the trimmed
  clip decodes to nothing, the full buffer is decoded once more — never
  after a timeout, because that worker may still be running.
- New `lib/services/utterance_audio.dart` (`UtteranceAudio.prepare`): cuts
  the capture to the detected speech region with 0.25 s before / 0.5 s after
  padding (a 10.5 s capture with 4.2 s voiced becomes ~5 s of decode),
  removes the ADC DC bias, and lifts a quiet clip by at most 4x toward 0.9
  peak while leaving an already loud clip untouched. Pure Dart,
  unit-tested; `feed` receives a fresh even-length PCM16 buffer.
- `voice_activity.dart`: tracks `speechStartSample` / `speechEndSample`
  while classifying chunks, including during the settle window so an early
  word is not trimmed away.
- Removed `AssistantService.partials`, the live session/partial fields, and
  the 30 s finalization path. `home_page.dart` is unchanged; it waits for
  the one decode under its existing busy state. `VoiceCaptureStats.retried`
  now means "the speech-trimmed pass heard nothing, so the full buffer was
  decoded". The old live `partial` text is legacy (empty on new captures)
  and its Admin line was removed.
- Checks: `flutter analyze` = only the 2 pre-existing info lints;
  `flutter test test/assistant_command_parser_test.dart
  test/voice_log_test.dart test/voice_activity_test.dart
  test/utterance_audio_test.dart` = **54/54 pass** (28 parser + 7 voice-log
  + 9 voice-activity + 10 utterance-audio). New tests: speech-region
  reporting, padding/clamping, whole-clip fallback, DC removal, quiet-clip
  gain, loud-clip passthrough, odd trailing bytes, empty input.
- NOT device-verified. Expected next APK: "code zero four L", "scan",
  "help", and "asa ko" each produce one entry with no `TimeoutException`; a
  normal command should finish a few seconds after the 1.2 s end silence.
  If an entry still says `full-buffer decode`, the trim cut the speech; if
  it says `0.0 s voiced` with a healthy peak, the detector floor is wrong —
  report the whole Admin entry, not just "nothing happened".

## Verification log (2026-11-20 pass 5 — predictable <= 8 s latency)

- User report on the Oppo A5 2020 (Snapdragon 665, Android 11, release APK):
  after pass 4, `scan` took ~8 s and `code zero four L` ~16 s after the
  user stopped speaking, and repeated runs varied. Target is **<= 8 s after
  the user stops speaking**, consistently. The 50 s timeout is gone.
- Diagnosis: two separate costs remained. whisper.cpp pads every clip to a
  30 s mel spectrogram and by default runs the encoder over all 1500
  audio-context positions, so even `scan` paid a large fixed encoder cost.
  The longer command added decoder work on top: greedy decoding used up to
  five candidates when temperature fallback ran, so noisy audio could pay
  several decoder passes. The 1.2 s end-silence rule also added a fixed
  tail, and in continuous street noise the VAD never fired at all, so the
  capture could run to the Home page's 12 s timer.
- Native fix: `whisper_ggml` 2.10.0 is now vendored at
  `third_party/whisper_ggml` and selected with a `dependency_overrides` path
  entry. `android/src/whisper/main.cpp` (`stream_run_inference`) sets
  `wparams.audio_ctx` from the actual `n_decode` length: 100 mel frames/s,
  two mel frames per encoder position, rounded up to 64, clamped to
  128..1500. A 5 s clip therefore uses 256 encoder positions instead of
  1500. The same block sets `greedy.best_of = 1` and
  `temperature_inc = 0.0f`, and enables `no_timestamps` (the app only needs
  text), so one capture performs one encoder pass and one decoder pass. The
  patch rationale is in `third_party/whisper_ggml/SEERUTA_PATCH.md`.
- Endpoint/tail fix: `VoiceActivityDetector.endSilenceSeconds` is now 0.8 s
  (was 1.2). New `maxSpeechSeconds = 7.5` ends capture 7.5 s after the first
  voiced chunk even when a loud street has no silence to key on, so the
  VAD no longer falls through to the 12 s Home timer. The full-buffer
  retry now runs only if the first decode finished inside a 3 s budget;
  a slow first decode is not followed by a second one.
- Diagnostics: `VoiceCaptureStats` now records `tailSeconds` (silence after
  the last voiced chunk) and `decodeMs` (wall-clock decoder time, including
  the retry). Admin > Voice Recognition prints `... · tail 0.8 s · decode
  2.4 s · peak ...`, so the after-speech time is visible per capture:
  `tailSeconds + decodeMs/1000`. Older persisted entries default both to 0.
- Checks: `flutter analyze` = only the 2 pre-existing info lints
  (`cebu_map_view.dart:282`, `cebu_style.dart:60`). `flutter test` =
  **97/97 pass** (2 new VAD tests: continuous noise ends at the 7.5 s cap,
  speech ends after exactly 0.8 s of silence; voice-log persistence now
  covers `tailSeconds`/`decodeMs` and legacy entries default to 0). The
  patched `main.cpp` also passes `g++ -std=c++17 -fsyntax-only` against the
  vendored whisper headers.
- NOT device-verified. Expected on the A5 2020 after the CI APK: `scan` and
  `code zero four L` both land roughly 2–5 s after speech; worst case in
  continuous noise is the 7.5 s cap plus a roughly 2–4 s decode. If a run
  is still slow, read the new Admin line: `tail` above ~1.5 s means the VAD
  cap/endpoint, `decode` above ~5 s means the native patch did not take
  effect or the phone is thermally throttled, and `full-buffer decode` means
  the retry ran.

## Verification log (2026-11-20 pass 6 — code-phrase transcript spam)

- User report on the pass-5 APK: saying a route code ("code zero eight G",
  or any jeep code) fills Admin > Voice Recognition with a long word
  sequence instead of the code. Natural commands were less affected.
- Diagnosis: the transcript shown in Admin is the raw whisper output, one
  entry per capture. whisper-tiny is open-vocabulary, and the initial prompt
  contained every real route code (`SeeRuta code 01K 03A ... 62B ...`).
  `no_context` clears only rolling text, not `initial_prompt`, so a
  code-shaped utterance could make the decoder continue that prompt list
  instead of transcribing the speaker. Pass 5 also sets
  `temperature_inc = 0` and `best_of = 1`, so whisper's repetition fallback
  was disabled and a loop was returned as-is. `no_timestamps = true` leaves
  no timestamp tokens to break the segment.
- Prompt fix: `AssistantService._prompt` now contains only the English +
  Cebuano command vocabulary and "code route"; the 35-code list was removed.
  `AssistantCommandParser` already normalizes digit/letter words and
  fuzzy-matches the real codes, so this does not remove code support.
- Decoder cap: `wparams.max_tokens = 32` in `stream_run_inference`, so even a
  loop cannot produce a paragraph. It also bounds wasted decoder work; a
  command needs only a few tokens.
- Log/parse guard: new `lib/services/transcript_cleanup.dart`
  (`collapseRepeatedPhrases`) collapses a phrase repeated three or more times
  consecutively, case-insensitively, before `VoiceLog` and the parser see
  it. Two repeats are left alone so a genuine "zero zero four" survives.
- Checks: `flutter analyze` = only the 2 pre-existing info lints.
  `flutter test` = **104/104 pass** (7 new cleanup tests). Patched
  `main.cpp` passes `g++ -std=c++17 -fsyntax-only`.
- NOT device-verified. Next APK: repeat 5 code trials (existing and
  nonexistent codes) and check that each Admin entry is one short phrase. If
  the transcript is still long but now capped, the prompt is no longer the
  trigger; the next step is to restore a single bounded temperature fallback
  (`temperature_inc = 0.2`, keep `best_of = 1`) rather than the old
  multi-candidate decode.

## Startup loading screen + permission prompts (2026-11-20)

- New `lib/pages/loading_screen.dart`: a static `LoadingScreen` — plain white
  `ColoredBox`, no spinner, with `assets/icon/ruta-icon.png` (the same 1024²
  artwork `flutter_launcher_icons` uses) centred at 160×160 with 36 px rounded
  corners. Android's own launch theme is already white
  (`res/drawable/launch_background.xml`), so there is no colour flash between
  the native splash and this screen.
- `lib/main.dart`: `MyApp.home` is now `StartupScreen` (new stateful gate), not
  `HomeScreen`. On the first frame it paints `LoadingScreen`, then starts three
  things at once and only leaves the loading screen when **all** of them are
  done:
  1. `RouteLoader.load()` — the jeepney catalogue (was previously loaded inside
     `HomeScreen._loadData`, which also owned the `CircularProgressIndicator`
     fallback; that spinner and the nullable `_routes` are gone).
  2. `OfflineMapAssets.prepare()` — the real "map loading": on first install
     copies the 41 MB `cebu_city.mbtiles` plus the glyphs to app storage and
     writes `style.json`. `HomePage` still calls it again on mount, which is now
     just the cheap existence check/style rewrite. Failures are logged and
     retried by `HomePage`, never block startup.
  3. Permission prompts, one at a time via `permission_handler`:
     `Permission.locationWhenInUse` → `Permission.camera` →
     `Permission.microphone`. Both granting and denying release the gate; a
     platform error is caught and logged too, so the screen can never hang.
- `HomeScreen` now takes a required `RouteState routes` from `StartupScreen`, so
  the tab shell opens with data already present (no first-frame flash).
- `android/app/src/main/AndroidManifest.xml`: added
  `android.permission.CAMERA` explicitly (the camera plugin also declares it;
  `permission_handler` needs it present to request camera without opening the
  scanner). `ACCESS_FINE/COARSE_LOCATION` and `RECORD_AUDIO` were already there.
- `ios/Runner/Info.plist`: added `NSCameraUsageDescription` and
  `NSMicrophoneUsageDescription` beside the existing location string. NOTE: the
  iOS Podfile has no `PERMISSION_*` preprocessor macros, which
  `permission_handler_apple` needs to actually return statuses on iOS
  (permissions would report denied); iOS is not built by the current workflows.
- Dependency: `permission_handler: ^12.0.1`, deliberately **not** 13.x.
  `permission_handler 13.0.2` resolves `permission_handler_android 14.1.1`,
  which declares `compileSdk = 37`, while Flutter 3.47.7's app default is
  `compileSdk 36` — AGP fails the build for a dependency that needs a newer
  compileSdk. 12.0.1 resolves `permission_handler_android 13.0.1`
  (`compileSdkVersion 35`, `minSdkVersion 19`), which builds under the existing
  app config with no `compileSdk` bump and no SDK 37 download on CI.
- Checks: `flutter analyze lib` = only the 2 pre-existing
  `use_null_aware_elements` info lints; `flutter test test/widget_test.dart`
  passes (the test pumps `MyApp`, which now shows the loading screen —
  `MissingPluginException`s from the permission/map plugins in the test
  environment are caught by the startup code). NOT device-verified: the dialog
  sequence on a cold start, the first-run 41 MB copy time behind the screen, and
  whether the white screen survives Android 12+ splash hand-off.

## Tab transitions: lazy pages + directional slide (2026-11-21)

- The `HomeScreen` `PageView` is gone. `animateToPage` moved *through* every
  page in between, so Home -> Profile built page 1 and `CodeScanPage.initState`
  opened the camera on the way past it. Tab switches are now a hand-built stack
  (`_buildPageStack`): the current page and the target page slide against each
  other, nothing else is built.
- Pages are lazy and sticky: `_builtPages` starts as `{Home}` and only gains a
  page when it is opened. Once opened a page stays mounted, parked fully
  offscreen (`FractionalTranslation` by 2x width) with `IgnorePointer` and
  `TickerMode(enabled: false)`, so the map and camera keep their state and no
  background page animates. Previously the PageView keep-alives did the same
  for pages it had built.
- Direction follows the *bar* order (`_tabOrder` = Home, Barangays, Camera,
  Profile), not the page indices (0 Home, 1 Camera, 2 Profile, 3 Barangays):
  moving right in the bar brings the page in from the right, moving left in
  from the left. Barangays sits second in the bar but last in the indices, so
  an index-based comparison would have reversed those two.
- `_slideTo(page)` owns the switch: it records `_leavingPage`, sets `_destIndex`
  immediately (the bar's selected pill updates at once) and animates
  `_slideController` 0 -> 1 (300 ms `easeInOut`). A tap mid-switch lands the
  running switch first so the next one starts from a settled page. Re-tapping
  the active tab is still a no-op, and the Konami B/A feed is unchanged.
- The drawer destinations and `RouteFocus.tabRequest` still call `_goTo`, so
  they use the same animation as the bar. The Admin reveal passes its own
  duration (1400 ms) and `ZombieLurch` curve to `_slideTo`.
- Checks: `flutter analyze lib` (only the 2 pre-existing lints), `flutter test
  test/widget_test.dart` passes. NOT device-verified: map re-render after its
  page is parked offscreen under `TickerMode(false)`.

## Locate moved from the burger menu to the bottom bar (2026-11-21)

- The Home burger panel no longer has the "My location" switch; that panel is
  back to Settings / Notifications / Help / About. `_locationSubtitle` went with
  it, since the bar button has no room for a subtitle.
- The blue `NavBarCenterButton` now runs the feature instead of showing the
  "coming soon" placeholder: it reveals Home (`_slideTo`, called directly so the
  tap does not feed the Konami sequence) and bumps `_locateRequests`, a
  `ValueNotifier<int>` owned by `HomeScreen` and passed to `HomePage`.
- `HomePage._showMyLocation` handles the tap: if GPS is off it runs the old
  enable-and-centre path (including the permission/service snackbars); if it is
  on and has a fix it flies to it at `_locationZoom`; if it is still waiting it
  arms `_centerOnNextFix` and shows "Waiting for GPS…" / "Still searching".
- `_comingSoon` in `HomeScreen` was removed with its last caller.
- Checks: `flutter analyze lib` = only the 2 pre-existing
  `use_null_aware_elements` info lints; `flutter test test/widget_test.dart`
  passes. NOT device-verified: the locate tap on a real GPS fix, and the map
  flying while it slides back into view.

## Splash preloads the shell + pages are never rebuilt (2026-11-21)

- The startup gate now mounts `HomeScreen` behind `LoadingScreen` as soon as
  the route catalogue is ready (`StartupScreen.build` is a `Stack` with an
  `IgnorePointer`-wrapped shell under an `AbsorbPointer`-wrapped splash). The
  splash comes off only after permissions, map-asset preparation and a
  two-second minimum from the first frame (`_minimumSplash`). MapLibre therefore
  builds and loads its style out of sight instead of after the white screen.
- `OfflineMapAssets.prepare()` is now shared: it caches its in-flight future
  (`_pending`) so the startup gate and `HomePage._prepareMap` await the same
  first-run MBTiles copy instead of racing two writers over the same files. The
  cache is cleared on failure so the Admin style-reload retry still works.
- Page layers in `_buildPageStack` carry `ValueKey<int>(index)`. Stack children
  used to be matched by position, and the list reorders during a switch
  (parked/outgoing/incoming), so moving between slots tore down and rebuilt a
  loaded page — the camera and Barangay pages re-initialised, and a jump could
  briefly mount the same page twice. Keys keep each page's State with its
  element, so once opened a page keeps its map/camera until the app exits.
- `test/widget_test.dart` now pumps past the two-second splash so the startup
  timer is not left pending when the tree is disposed.
- Checks: `flutter analyze lib` = only the 2 pre-existing
  `use_null_aware_elements` info lints; `flutter test test/widget_test.dart`
  passes. NOT device-verified: splash-to-map hand-off, and map interaction after
  the splash is removed (the view was built under it).

## Only the map page stays mounted + splash fade (2026-11-21)

Supersedes the "pages are never rebuilt" bullet above.

- `_builtPages` is pruned at the end of every slide in `_slideTo`: only
  `_homePage` survives. The page that just slid out (and any page left over from
  an interrupted switch) is unmounted offscreen, so reopening Camera, Barangays
  or Profile constructs it fresh. HomePage stays mounted for the life of the
  shell, so the map, its style and its last camera position are never rebuilt.
- The `ValueKey<int>(index)` on page layers is still required, now mainly for
  the always-mounted map: when Home moves between the parked/outgoing/incoming
  slots, keyed matching keeps its element and State instead of recreating the
  map page by position.
- Splash: once the two-second minimum, permissions and map-asset preparation are
  all done, `_splashDone` fades `LoadingScreen` out over 350 ms with
  `AnimatedOpacity`, and `onEnd` removes it from the stack entirely
  (`_splashRemoved`). Taps fall through to the revealed map as soon as the fade
  starts, and the solid splash still absorbs them before that.
- Checks: `flutter analyze lib test` = only the 2 pre-existing
  `use_null_aware_elements` info lints; `flutter test test/widget_test.dart`
  passes. NOT device-verified: splash fade over the native map view, and the
  camera/Barangays teardown-then-reopen path on a real device.

## Startup fade no longer depends on an implicit animation (2026-11-21)

- `StartupScreen` now owns an explicit `AnimationController` (`_splashFade`,
  value 1 = solid) and fades `LoadingScreen` with `FadeTransition`. After the
  catalogue, map assets, permissions and the two-second minimum are all done it
  sets `_splashDone`, waits one painted frame (`endOfFrame`), then calls
  `reverse(from: 1)`; the status listener removes the splash on `dismissed`.
- Why: `AnimatedOpacity` only animates when it sees an opacity change between
  builds. On first boot the catalogue, asset preparation and the permission
  answers can all resolve in the same frame, so the implicit animation was
  created already at 0 — no fade, no `onEnd`, and the splash stayed in the tree
  invisibly. The explicit controller always starts from a painted solid frame,
  including immediately after the permission prompts are accepted or declined.
- Checks: `flutter analyze lib test` = only the 2 pre-existing
  `use_null_aware_elements` info lints; `flutter test test/widget_test.dart`
  passes. NOT device-verified: the first-boot permission-to-fade sequence.

## Startup loading screen minimum duration set to 5 seconds (2026-11-21)

- `_minimumSplash` in `StartupScreen` (`lib/main.dart`) updated from 2 seconds to
  5 seconds (`Duration(seconds: 5)`).
- `test/widget_test.dart` pump duration updated to 5 seconds (`Duration(seconds: 5)`)
  so test pumps past the 5-second splash without leaving pending timers.
- `lib/pages/loading_screen.dart` documentation updated to state 5 seconds.
- Checks: `flutter analyze lib test`, `flutter test test/widget_test.dart`.
