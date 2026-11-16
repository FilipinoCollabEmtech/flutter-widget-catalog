import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../models/landmark.dart';
import '../models/route.dart';
import '../services/landmark_service.dart';
import '../services/route_planner.dart';
import 'cebu_boundary_layer.dart' show kCebuHome;
import 'cebu_map_view.dart';
import 'location_service.dart';
import 'offline_map_assets.dart';

/// Home tab: search bar with a circular burger button on its right.
/// Tapping the button plays a press animation, morphs the icon,
/// and pops a half-width menu panel out of the button.
///
/// The map is MapLibre (native, GPU) instead of flutter_map.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.showZoomInfo,
    required this.debugStats,
    required this.showVectorTiles,
    required this.showCebuBoundary,
    required this.showCebuArrow,
    required this.showUserLocation,
    required this.showZoomReadout,
    required this.rebuildStyleKey,
    required this.landmarks,
    required this.routes,
  });

  /// When true, a small zoom/center readout shows in the top right.
  final ValueListenable<bool> showZoomInfo;
  final LandmarkService landmarks;
  final RouteState routes;

  /// Sink for live debug telemetry (shown on the Admin page).
  final ValueNotifier<Map<String, String>> debugStats;

  /// When true, the vector tile layer renders roads, landuse, buildings, etc.
  final ValueListenable<bool> showVectorTiles;

  /// When true, the grey boundary overlay outside Cebu renders.
  final ValueListenable<bool> showCebuBoundary;

  /// When true, the double-arrow direction button renders.
  final ValueListenable<bool> showCebuArrow;

  /// When true, the user location dot / accuracy circle renders.
  final ValueListenable<bool> showUserLocation;

  /// When true, the zoom / center readout overlay renders.
  final ValueListenable<bool> showZoomReadout;

  /// Bumped by the Admin panel to request a map style rebuild.
  final ValueNotifier<int> rebuildStyleKey;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin<HomePage> {
  /// Keeps the map (and its camera position) alive when you switch tabs.
  @override
  bool get wantKeepAlive => true;

  static const double _burgerSize = 56;
  static const double _edgePadding = 16;

  /// MapLibre zoom for "show me where I am" (flutter_map's 15).
  static const double _locationZoom = 14;

  bool _open = false;
  bool _pressed = false;
  bool _searchActive = false;

  /// Live search query typed into the SearchBar.
  final ValueNotifier<String> _query = ValueNotifier<String>('');
  final TextEditingController _searchController = TextEditingController();

  /// Results for the current [_query], kept in a listenable so the dropdown
  /// re-renders as the user types.
  final ValueNotifier<List<Landmark>> _results = ValueNotifier(const []);

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

  OfflineMapPaths? _paths;
  String? _mapError;

  ml.MapLibreMapController? _map;
  final ValueNotifier<ml.CameraPosition?> _camera =
      ValueNotifier<ml.CameraPosition?>(null);

  final LocationService _location = LocationService();
  bool _centerOnNextFix = false;

  @override
  void initState() {
    super.initState();
    _location.addListener(_onLocationChanged);
    _prepareMap();
    widget.rebuildStyleKey.addListener(_onRebuildStyleKey);
  }

  void _onRebuildStyleKey() {
    _prepareMap();
  }

  @override
  void dispose() {
    _location.removeListener(_onLocationChanged);
    _location.dispose();
    _camera.dispose();
    _menuAnim.dispose();
    _icon.dispose();
    _query.dispose();
    _results.dispose();
    _searchController.dispose();
    widget.rebuildStyleKey.removeListener(_onRebuildStyleKey);
    super.dispose();
  }

  /// Copies the MBTiles + glyphs to app storage and writes the style file.
  Future<void> _prepareMap() async {
    try {
      final paths = await OfflineMapAssets.prepare();
      if (!mounted) return;
      setState(() => _paths = paths);
      widget.debugStats.value = {
        'Renderer': 'MapLibre (native)',
        'Style': paths.stylePath,
      };
    } catch (error, stackTrace) {
      debugPrint('Failed to prepare offline map: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => _mapError = error.toString());
      }
    }
  }

  // ---- Camera ---------------------------------------------------------------

  /// Smooth, native camera glide.
  void _flyTo(double lat, double lng, double zoom) {
    _map?.animateCamera(
      ml.CameraUpdate.newLatLngZoom(ml.LatLng(lat, lng), zoom),
      duration: const Duration(milliseconds: 1200),
    );
  }

  // ---- Location -----------------------------------------------------------

  /// Glides the camera to the user once, on the first fix after enabling.
  void _onLocationChanged() {
    final position = _location.position;
    if (!_centerOnNextFix || position == null || _map == null) return;
    _centerOnNextFix = false;
    _flyTo(position.latitude, position.longitude, _locationZoom);
  }

  // ---- Search ---------------------------------------------------------------

  /// Runs on every keystroke. Landmark-only: matches the name, category,
  /// barangay or address of a POI. Barangay boundaries are not searchable —
  /// they are drawn for context and highlighted when a route crosses them.
  void _search(String query) {
    _query.value = query;
    _results.value = widget.landmarks.search(query);
  }

  /// Selects the top result: flies the map to it and, if a destination is
  /// already set, plans a jeepney route to it.
  void _pickFirstResult() {
    final hit = _results.value.isEmpty ? null : _results.value.first;
    if (hit == null) return;
    _searchActive = false;
    _query.value = '';
    _results.value = const [];
    _searchController.clear();
    _flyTo(hit.point.latitude, hit.point.longitude, 15);

    final origin = widget.routes.origin.value;
    if (origin != null) {
      widget.routes.plan(
        origin,
        LandmarkRef(hit.name, hit.point, hit.code),
      );
    }
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
            alignment: Alignment(1 - _burgerSize / panelWidth, -1),
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
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final scheme = Theme.of(context).colorScheme;

    // About half the screen, but never too narrow for the labels.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = screenWidth * 0.5 < 220 ? 220.0 : screenWidth * 0.5;

    return Stack(
      children: [
        // Layer 1 (behind): full-screen map
        Positioned.fill(
          child: _paths != null
              ? CebuMapView(
                  stylePath: _paths!.stylePath,
                  location: _location,
                  cameraNotifier: _camera,
                  onMapReady: (controller) => _map = controller,
                  onHomePressed: () =>
                      _flyTo(kCebuHome.latitude, kCebuHome.longitude, 10),
                  showCebuBoundary: widget.showCebuBoundary,
                  showUserLocation: widget.showUserLocation,
                  showCebuArrow: widget.showCebuArrow,
                  showVectorTiles: widget.showVectorTiles,
                  styleLayerIds: _paths!.styleLayerIds,
                  arrowPadding: EdgeInsets.fromLTRB(
                    16,
                    MediaQuery.paddingOf(context).top + 96,
                    16,
                    // Stay above the floating bottom bar.
                    MediaQuery.paddingOf(context).bottom + 16,
                  ),
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
                return ValueListenableBuilder<ml.CameraPosition?>(
                  valueListenable: _camera,
                  builder: (context, camera, _) {
                    final zoom = camera?.zoom ?? 10;
                    final lat = camera?.target.latitude ?? kCebuHome.latitude;
                    final lng = camera?.target.longitude ?? kCebuHome.longitude;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        // MapLibre zoom = flutter_map zoom - 1.
                        'Zoom ${zoom.toStringAsFixed(2)}\n'
                        'Lat  ${lat.toStringAsFixed(5)}\n'
                        'Lng  ${lng.toStringAsFixed(5)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          height: 1.3,
                        ),
                      ),
                    );
                  },
                );
              },
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
                      Expanded(
                        child: SearchBar(
                          controller: _searchController,
                          hintText: 'Search landmarks...',
                          leading: const Icon(Icons.search),
                          trailing: _query.value.isEmpty
                              ? null
                              : [
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      _search('');
                                    },
                                  ),
                                ],
                          onTap: () => _searchActive = true,
                          onChanged: _search,
                          onSubmitted: (_) => _pickFirstResult(),
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
              // Search dropdown — appears under the bar while typing.
              if (_searchActive && _results.value.isNotEmpty)
                Positioned(
                  top: _edgePadding + 8,
                  left: _edgePadding,
                  right: _edgePadding + 12 + _burgerSize + 12,
                  child: ValueListenableBuilder<List<Landmark>>(
                    valueListenable: _results,
                    builder: (context, results, _) {
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: Material(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                          elevation: 6,
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const ClampingScrollPhysics(),
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final l = results[index];
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  _iconFor(l.category),
                                  size: 20,
                                  color: scheme.primary,
                                ),
                                title: Text(
                                  l.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  [
                                    if (l.barangay != null) l.barangay!,
                                    if (l.address != null) l.address!,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onTap: () {
                                  _searchActive = false;
                                  _query.value = '';
                                  _results.value = const [];
                                  _searchController.clear();
                                  _flyTo(l.point.latitude, l.point.longitude, 15);

                                  final origin = widget.routes.origin.value;
                                  if (origin != null) {
                                    widget.routes.plan(
                                      origin,
                                      LandmarkRef(l.name, l.point, l.code),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconFor(String category) => switch (category) {
        'park' => Icons.park,
        'mall' => Icons.store,
        'school' => Icons.school,
        'hospital' => Icons.local_hospital,
        'terminal' => Icons.terminal,
        'worship' => Icons.place,
        'government' => Icons.account_balance,
        'tourist' => Icons.photo_camera,
        'transit' => Icons.directions,
        'port' => Icons.directions_boat,
        'airport' => Icons.flight,
        _ => Icons.place,
      };
}
