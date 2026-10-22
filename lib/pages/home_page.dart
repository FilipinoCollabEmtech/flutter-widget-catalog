import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

/// Home tab: search bar with a circular burger button on its right.
/// Tapping the button plays a press animation, morphs the icon,
/// and expands a little menu panel underneath.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  bool _pressed = false;

  late final AnimationController _icon = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  MbTilesTileProvider? _tileProvider;
  String? _mapError;

  @override
  void initState() {
    super.initState();
    _loadOfflineMap();
  }

  @override
  void dispose() {
    _tileProvider?.dispose();
    _icon.dispose();
    super.dispose();
  }

  Future<void> _loadOfflineMap() async {
    try {
      // Get the app's local storage directory.
      final directory = await getApplicationSupportDirectory();

      final mapFile = File(
        '${directory.path}/cebu_city.mbtiles',
      );

      // Copy the MBTiles asset to local storage if it doesn't
      // already exist there.
      if (!await mapFile.exists()) {
        final data = await rootBundle.load(
          'assets/maps/cebu_city.mbtiles',
        );

        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );

        await mapFile.writeAsBytes(
          bytes,
          flush: true,
        );
      }

      // Open the MBTiles database from the filesystem.
      final provider = MbTilesTileProvider.fromPath(
        path: mapFile.path,
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
      SnackBar(
        content: Text('$label — example only'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bool mapReady = _tileProvider != null;

    return Stack(
      children: [
        // Layer 1 (behind): full-screen map
        Positioned.fill(
          child: mapReady
              ? FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(
                      10.3157,
                      123.8854,
                    ),
                    initialZoom: 13,
                    minZoom: 10,
                    maxZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      tileProvider: _tileProvider!,
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
        // Layer 2 (front): floating search + menu panel
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
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
                onTapDown: (_) {
                  setState(() => _pressed = true);
                },
                onTapUp: (_) {
                  setState(() => _pressed = false);
                },
                onTapCancel: () {
                  setState(() => _pressed = false);
                },
                onTap: _toggle,
                child: AnimatedScale(
                  scale: _pressed ? 0.85 : 1.0,
                  duration: const Duration(
                    milliseconds: 120,
                  ),
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
          padding: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            0,
          ),
          child: AnimatedSize(
            duration: const Duration(
              milliseconds: 250,
            ),
            curve: Curves.easeInOut,
            child: _open
                ? Card(
                    margin: const EdgeInsets.only(
                      top: 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.settings_outlined,
                          ),
                          title: const Text('Settings'),
                          onTap: () {
                            _example('Settings');
                          },
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.notifications_outlined,
                          ),
                          title: const Text('Notifications'),
                          onTap: () {
                            _example('Notifications');
                          },
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.help_outline,
                          ),
                          title: const Text(
                            'Help & feedback',
                          ),
                          onTap: () {
                            _example('Help & feedback');
                          },
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.info_outline,
                          ),
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
