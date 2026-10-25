import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import 'animated_map_mover.dart';
import 'cebu_boundary_layer.dart';
import 'location_service.dart';
import 'mbtiles_vector_tile_provider.dart';
import 'user_location_layer.dart';

/// OSM Liberty theme trimmed for mobile performance.
///
/// Layers that are expensive to draw (POIs, road shields, one-way arrows,
/// country labels, 3D buildings, natural_earth) are dropped. Matching is done
/// by id prefix so it works regardless of the exact suffixes in the theme.
/// To see every id, temporarily print `base.layers.map((l) => l.id)`.
vtr.Theme _buildOfflineTheme() {
  final base = vtr.ProvidedThemes.lightTheme();
  const droppedExact = <String>{'natural_earth', 'building-3d', 'place_other'};
  const droppedPrefixes = <String>[
    'poi',
    'road_shield',
    'road_one_way',
    'label_country',
    'label_continent',
    'highway-shield',
    'airport',
  ];

  bool keep(String id) =>
      !droppedExact.contains(id) &&
      !droppedPrefixes.any((prefix) => id.startsWith(prefix));

  return vtr.Theme(
    id: base.id,
    version: base.version,
    layers: base.layers.where((l) => keep(l.id)).toList(growable: false),
  );
}

/// Home tab: search bar with a circular burger button on its right.
/// Tapping the button plays a press animation, morphs the icon,
/// and expands a little menu panel underneath.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.showZoomInfo});

  /// When true, a small zoom/center readout shows in the top right.
  final ValueListenable<bool> showZoomInfo;

  @override
  State<HomePage> createState() => _HomePageState();
}

// TickerProviderStateMixin (not Single...) because we now run two
// AnimationControllers: the menu icon and the camera move.
class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin<HomePage> {
  /// Keeps the map (and its camera position) alive when you switch tabs.
  @override
  bool get wantKeepAlive => true;

  bool _open = false;
  bool _pressed = false;

  ///   OSM Liberty theme with a balanced mobile-friendly subset.
  late final vtr.Theme _vectorThemeInstance = _buildOfflineTheme();

  late final AnimationController _icon = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  MbtilesVectorTileProvider? _tileProvider;
  String? _mapError;

  final MapController _mapController = MapController();
  late final AnimatedMapMover _mover = AnimatedMapMover(
    vsync: this,
    mapController: _mapController,
  );
  final LocationService _location = LocationService();
  final ValueNotifier<MapCamera?> _camera = ValueNotifier<MapCamera?>(null);
  bool _centerOnNextFix = false;

  @override
  void initState() {
    super.initState();
    _location.addListener(_onLocationChanged);
    _loadOfflineMap();
  }

  @override
  void dispose() {
    _location.removeListener(_onLocationChanged);
    _location.dispose();
    _mover.dispose();
    _mapController.dispose();
    _camera.dispose();
    _tileProvider?.dispose();
    _icon.dispose();
    super.dispose();
  }

  Future<void> _loadOfflineMap() async {
    try {
      // Get the app's local storage directory.
      final directory = await getApplicationSupportDirectory();

      final mapFile = File('${directory.path}/cebu_city.mbtiles');

      // Copy the MBTiles asset to local storage if it doesn't
      // already exist there.
      if (!await mapFile.exists()) {
        final data = await rootBundle.load('assets/maps/cebu_city.mbtiles');

        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );

        await mapFile.writeAsBytes(bytes, flush: true);
      }

      // Open the vector MBTiles database in a worker isolate so SQLite reads
      // do not block the UI while zooming.
      final provider = await MbtilesVectorTileProvider.create(
        mbtilesPath: mapFile.path,
        maxZoom: 14,
      );

      if (!mounted) {
        provider.dispose();
        return;
      }

      setState(() {
        _tileProvider = provider;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load offline map: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          _mapError = error.toString();
        });
      }
    }
  }

  /// Publishes the camera for the zoom readout. If the map reports a change
  /// while Flutter is mid-build, wait until the frame ends.
  void _setCamera(MapCamera camera) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _camera.value = camera;
      });
    } else {
      _camera.value = camera;
    }
  }

  // ---- Location -----------------------------------------------------------

  /// Glides the camera to the user once, on the first fix after enabling.
  void _onLocationChanged() {
    final position = _location.position;
    if (!_centerOnNextFix || position == null || _tileProvider == null) {
      return;
    }
    _centerOnNextFix = false;
    _mover.animateTo(position, zoom: 15); // 15 = your MapOptions maxZoom
  }

  Future<void> _toggleLocation() async {
    if (_location.isEnabled) {
      _centerOnNextFix = false;
      _location.disable();
      return;
    }

    _centerOnNextFix = true;
    await _location.enable();
    if (!mounted) return;

    switch (_location.status) {
      case LocationStatus.serviceDisabled:
        _showLocationMessage(
          'Location services are turned off.',
          actionLabel: 'Settings',
          onAction: _location.openLocationSettings,
        );
      case LocationStatus.denied:
        _showLocationMessage('Location permission was denied.');
      case LocationStatus.deniedForever:
        _showLocationMessage(
          'Location permission is blocked. Enable it in app settings.',
          actionLabel: 'Settings',
          onAction: _location.openAppSettings,
        );
      case LocationStatus.error:
        _showLocationMessage('Could not get your location.');
      case LocationStatus.active:
        if (_location.approximate) {
          _showLocationMessage(
            'Only approximate location is allowed, so GPS is not used. '
            'Allow "Precise" location in app settings.',
            actionLabel: 'Settings',
            onAction: _location.openAppSettings,
          );
        }
      case LocationStatus.off:
      case LocationStatus.starting:
        break;
    }
  }

  void _showLocationMessage(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
  }

  String? _locationSubtitle() {
    switch (_location.status) {
      case LocationStatus.starting:
        return 'Starting…';
      case LocationStatus.active:
        if (_location.position == null) {
          return _location.searchingSlow
              ? 'Still searching… go outdoors with a clear view of the sky'
              : 'Waiting for GPS…';
        }
        return _location.approximate ? 'Approximate location only' : null;
      default:
        return null;
    }
  }

  // ---- Menu ---------------------------------------------------------------

  void _toggle() {
    setState(() => _open = !_open);

    if (_open) {
      _icon.forward();
    } else {
      _icon.reverse();
    }
  }

  void _example(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — example only')),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final scheme = Theme.of(context).colorScheme;

    final bool mapReady = _tileProvider != null;

    return Stack(
      children: [
        // Layer 1 (behind): full-screen map
        Positioned.fill(
          child: mapReady
              ? FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(10.3157, 123.8854),
                    initialZoom: 11,
                    // If the user drags the map mid-glide, let go of the camera.
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture) _mover.cancel();
                      _setCamera(position);
                    },
                  ),
                  children: [
                    VectorTileLayer(
                      tileProviders: TileProviders({
                        'openmaptiles': _tileProvider!,
                      }),
                      theme: _vectorThemeInstance,
                      layerMode: VectorTileLayerMode.vector,
                      maximumZoom: 14,
                      concurrency: 6,
                      memoryTileCacheMaxSize: 64 * 1024 * 1024,
                      memoryTileDataCacheMaxSize: 80,
                      textCacheMaxSize: 200,
                      maximumTileSubstitutionDifference: 3,
                    ),
                    const CebuOutsideLayer(),
                    UserLocationLayer(service: _location),
                    CebuDirectionArrow(
                      // Keep clear of the search bar / menu at the top.
                      padding: EdgeInsets.fromLTRB(
                        16,
                        MediaQuery.paddingOf(context).top + 96,
                        16,
                        24,
                      ),
                      onTap: () => _mover.animateTo(kCebuHome, zoom: 11),
                    ),
                  ],
                )
              : Center(
                  child: _mapError == null
                      ? const CircularProgressIndicator()
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Failed to load offline map:\n$_mapError',
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
        ),
        // Debug readout (toggle in the Admin tab), top right under the search row.
        Positioned(
          top: 80,
          right: 16,
          child: IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: widget.showZoomInfo,
              builder: (context, show, _) {
                if (!show) return const SizedBox.shrink();
                return ValueListenableBuilder<MapCamera?>(
                  valueListenable: _camera,
                  builder: (context, camera, _) {
                    const initial = LatLng(10.3157, 123.8854);
                    final zoom = camera?.zoom ?? 11;
                    final center = camera?.center ?? initial;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: StreamBuilder<int>(
                        // Refresh the tile-loading stats twice a second.
                        stream: Stream.periodic(
                          const Duration(milliseconds: 500),
                          (i) => i,
                        ),
                        builder: (context, _) => Text(
                          'Zoom ${zoom.toStringAsFixed(2)}\n'
                          'Lat  ${center.latitude.toStringAsFixed(5)}\n'
                          'Lng  ${center.longitude.toStringAsFixed(5)}\n'
                          'Tiles ${_tileProvider?.gate.stats ?? '-'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            height: 1.3,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        // Layer 2 (front): floating search + menu panel
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: SearchBar(
                        hintText: 'Search...',
                        leading: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTapDown: (_) => setState(() => _pressed = true),
                      onTapUp: (_) => setState(() => _pressed = false),
                      onTapCancel: () => setState(() => _pressed = false),
                      onTap: _toggle,
                      child: AnimatedScale(
                        scale: _pressed ? 0.85 : 1.0,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.surfaceContainerHigh,
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 4,
                                offset: Offset(0, 2),
                                color: Colors.black12,
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedIcon(
                              icon: AnimatedIcons.menu_close,
                              progress: _icon,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _open
                      ? Card(
                          margin: const EdgeInsets.only(top: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListenableBuilder(
                                listenable: _location,
                                builder: (context, _) {
                                  final subtitle = _locationSubtitle();
                                  return SwitchListTile(
                                    secondary: const Icon(Icons.my_location),
                                    title: const Text('Show my location'),
                                    subtitle: subtitle == null
                                        ? null
                                        : Text(subtitle),
                                    value: _location.isEnabled,
                                    onChanged: (_) => _toggleLocation(),
                                  );
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.settings_outlined),
                                title: const Text('Settings'),
                                onTap: () => _example('Settings'),
                              ),
                              ListTile(
                                leading: const Icon(
                                  Icons.notifications_outlined,
                                ),
                                title: const Text('Notifications'),
                                onTap: () => _example('Notifications'),
                              ),
                              ListTile(
                                leading: const Icon(Icons.help_outline),
                                title: const Text('Help & feedback'),
                                onTap: () => _example('Help & feedback'),
                              ),
                              ListTile(
                                leading: const Icon(Icons.info_outline),
                                title: const Text('About'),
                                onTap: () {
                                  showAboutDialog(
                                    context: context,
                                    applicationName: 'SeeRuta',
                                    applicationVersion: '1.0.0',
                                  );
                                },
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
