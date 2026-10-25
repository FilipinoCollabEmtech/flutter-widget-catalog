import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import 'animated_map_mover.dart';
import 'location_service.dart';
import 'mbtiles_vector_tile_provider.dart';
import 'user_location_layer.dart';

/// OSM Liberty theme with the most expensive layers removed.
///
/// POIs, 3D buildings, rail/transit, shields, one-way arrows, and
/// country/continent labels are dropped to keep zooming responsive. Roads,
/// water, landuse, flat buildings, and place/road labels are kept.
vtr.Theme _buildOfflineTheme() {
  final base = vtr.ProvidedThemes.lightTheme();
  const droppedLayerIds = <String>{
    'natural_earth',
    'building-3d',
    'poi_z16',
    'poi_z15',
    'poi_z14',
    'poi_transit',
    'road_shield',
    'road_one_way_arrow',
    'road_one_way_arrow_opposite',
    'road_major_rail',
    'road_major_rail_hatching',
    'road_transit_rail',
    'road_transit_rail_hatching',
    'tunnel_major_rail',
    'tunnel_major_rail_hatching',
    'tunnel_transit_rail',
    'tunnel_transit_rail_hatching',
    'bridge_major_rail',
    'bridge_major_rail_hatching',
    'bridge_transit_rail',
    'bridge_transit_rail_hatching',
    'state',
    'country_3',
    'country_2',
    'country_1',
    'continent',
    'place_other',
  };

  return vtr.Theme(
    id: base.id,
    version: base.version,
    layers: base.layers
        .where((layer) => !droppedLayerIds.contains(layer.id))
        .toList(growable: false),
  );
}

/// Home tab: search bar with a circular burger button on its right.
/// Tapping the button plays a press animation, morphs the icon,
/// and pops a half-width menu panel out of the button.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// TickerProviderStateMixin (not Single...) because we run two
// AnimationControllers: the menu icon/panel and the camera move.
class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  static const double _burgerSize = 56;
  static const double _edgePadding = 16;

  bool _open = false;
  bool _pressed = false;

  /// OSM Liberty theme with expensive POI/3D/rail layers removed.
  late final vtr.Theme _vectorThemeInstance = _buildOfflineTheme();

  /// Drives both the burger icon morph and the menu panel pop-out.
  late final AnimationController _icon = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  late final CurvedAnimation _menuAnim = CurvedAnimation(
    parent: _icon,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  MbtilesVectorTileProvider? _tileProvider;
  String? _mapError;

  final MapController _mapController = MapController();
  late final AnimatedMapMover _mover = AnimatedMapMover(
    vsync: this,
    mapController: _mapController,
  );
  final LocationService _location = LocationService();
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
    _tileProvider?.dispose();
    _menuAnim.dispose();
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

  /// Short strings: the menu panel is only about half the screen wide.
  String? _locationSubtitle() {
    switch (_location.status) {
      case LocationStatus.starting:
        return 'Starting…';
      case LocationStatus.active:
        if (_location.position == null) {
          return _location.searchingSlow
              ? 'Still searching — try outdoors'
              : 'Waiting for GPS…';
        }
        return _location.approximate ? 'Approximate only' : null;
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

  void _closeMenu() {
    if (_open) _toggle();
  }

  void _example(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — example only')),
    );
  }

  Widget _menuTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      dense: true,
      horizontalTitleGap: 8,
      minLeadingWidth: 24,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        _closeMenu();
        onTap();
      },
    );
  }

  /// Half-screen panel that scales out of the burger button.
  Widget _buildMenuPanel(double panelWidth) {
    return AnimatedBuilder(
      animation: _icon,
      // Nothing to build or hit-test while fully closed.
      builder: (context, child) =>
          _icon.isDismissed ? const SizedBox.shrink() : child!,
      child: IgnorePointer(
        ignoring: !_open,
        child: FadeTransition(
          opacity: _menuAnim,
          child: ScaleTransition(
            scale: _menuAnim,
            // Pivot near the burger's center (it sits ~28px in from the
            // panel's right edge) so the panel appears to grow out of it.
            alignment: Alignment(1 - (_burgerSize) / panelWidth, -1),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 6,
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListenableBuilder(
                    listenable: _location,
                    builder: (context, _) {
                      final subtitle = _locationSubtitle();
                      return SwitchListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        secondary: const Icon(Icons.my_location),
                        title: const Text('My location'),
                        subtitle: subtitle == null ? null : Text(subtitle),
                        value: _location.isEnabled,
                        onChanged: (_) => _toggleLocation(),
                      );
                    },
                  ),
                  _menuTile(Icons.settings_outlined, 'Settings',
                      () => _example('Settings')),
                  _menuTile(Icons.notifications_outlined, 'Notifications',
                      () => _example('Notifications')),
                  _menuTile(Icons.help_outline, 'Help & feedback',
                      () => _example('Help & feedback')),
                  _menuTile(Icons.info_outline, 'About', () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'SeeRuta',
                      applicationVersion: '1.0.0',
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bool mapReady = _tileProvider != null;

    // About half the screen, but never too narrow for the labels.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = screenWidth * 0.5 < 220 ? 220.0 : screenWidth * 0.5;

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
                    minZoom: 11,
                    maxZoom: 15,
                    cameraConstraint: CameraConstraint.contain(
                      bounds: LatLngBounds(LatLng(10.0, 123.48), LatLng(10.6, 124.2)),
                    ),
                    // If the user drags the map mid-glide, let go of the camera.
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture) _mover.cancel();
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
                      memoryTileCacheMaxSize: 16 * 1024 * 1024,
                      memoryTileDataCacheMaxSize: 30,
                      fileCacheMaximumSizeInBytes: 100 * 1024 * 1024,
                      textCacheMaxSize: 200,
                      maximumTileSubstitutionDifference: 1,
                    ),
                    UserLocationLayer(service: _location),
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

        // Layer 2: while the menu is open, a tap anywhere else closes it.
        if (_open)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeMenu,
            ),
          ),

        // Layer 3 (front): floating search + burger, and the menu panel.
        SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _edgePadding,
                    _edgePadding,
                    _edgePadding,
                    0,
                  ),
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
                            width: _burgerSize,
                            height: _burgerSize,
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
              ),
              // Right-aligned under the burger, 8px gap.
              Positioned(
                top: _edgePadding + _burgerSize + 8,
                right: _edgePadding,
                width: panelWidth,
                child: _buildMenuPanel(panelWidth),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
