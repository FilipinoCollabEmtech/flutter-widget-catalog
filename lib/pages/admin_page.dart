import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../pages/mbtiles_vector_tile_provider.dart';

/// Admin tab: debug switches and live telemetry.
class AdminPage extends StatefulWidget {
  const AdminPage({
    super.key,
    required this.showZoomInfo,
    required this.debugStats,
    required this.showVectorTiles,
    required this.showCebuBoundary,
    required this.showCebuArrow,
    required this.showUserLocation,
    required this.showRoutePolyline,
    required this.showBarangayPolygons,
    required this.showBarangayLabels,
    required this.showZoomReadout,
  });

  final ValueNotifier<bool> showZoomInfo;
  final ValueNotifier<Map<String, String>> debugStats;
  final ValueNotifier<bool> showVectorTiles;
  final ValueNotifier<bool> showCebuBoundary;
  final ValueNotifier<bool> showCebuArrow;
  final ValueNotifier<bool> showUserLocation;
  final ValueNotifier<bool> showRoutePolyline;
  final ValueNotifier<bool> showBarangayPolygons;
  final ValueNotifier<bool> showBarangayLabels;
  final ValueNotifier<bool> showZoomReadout;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Admin', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),

        // ---- Debug switches ----
        const Text('Debug switches', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: widget.showZoomInfo,
                builder: (context, value, _) => SwitchListTile(
                  secondary: const Icon(Icons.zoom_in),
                  title: const Text('Show zoom level'),
                  subtitle: const Text(
                    'Shows zoom level and map center in the top right of the Home tab.',
                  ),
                  value: value,
                  onChanged: (v) => widget.showZoomInfo.value = v,
                ),
              ),
              const Divider(height: 1),
              ValueListenableBuilder<bool>(
                valueListenable: MbtilesVectorTileProvider.debugTelemetry,
                builder: (context, enabled, _) => SwitchListTile(
                  secondary: const Icon(Icons.bug_report),
                  title: const Text('Debug telemetry'),
                  subtitle: const Text(
                    'Logs every tile read, generation bump, and discard to the '
                        'console so you can diagnose pinch-and-zoom lag.',
                  ),
                  value: enabled,
                  onChanged: (v) => MbtilesVectorTileProvider.debugTelemetry.value = v,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.bug_report),
                title: const Text('Force tile reload'),
                subtitle: const Text('Clears the tile gate and forces a re-read.'),
                onTap: () {
                  debugPrint('Admin: force tile reload requested');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tile reload — not wired yet')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Refresh stats'),
                subtitle: const Text('Manually refresh the debug telemetry below.'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Stats refresh triggered')),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---- Layer visibility toggles ----
        const Text('Layer visibility', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildToggle(
                icon: Icons.layers,
                title: 'Vector tiles',
                subtitle: 'Roads, landuse, buildings, labels (MBTiles)',
                value: widget.showVectorTiles,
              ),
              _buildToggle(
                icon: Icons.layers,
                title: 'Cebu boundary blur',
                subtitle: 'Grey fade outside Cebu island',
                value: widget.showCebuBoundary,
              ),
              _buildToggle(
                icon: Icons.directions,
                title: 'Direction arrow',
                subtitle: 'Points toward Cebu home point',
                value: widget.showCebuArrow,
              ),
              _buildToggle(
                icon: Icons.person_pin,
                title: 'User location',
                subtitle: 'User dot / accuracy circle',
                value: widget.showUserLocation,
              ),
              _buildToggle(
                icon: Icons.route,
                title: 'Route polyline',
                subtitle: 'Blue line between route waypoints',
                value: widget.showRoutePolyline,
              ),
              _buildToggle(
                icon: Icons.map,
                title: 'Barangay polygons',
                subtitle: 'Colored territory polygons',
                value: widget.showBarangayPolygons,
              ),
              _buildToggle(
                icon: Icons.label,
                title: 'Barangay labels',
                subtitle: 'Name labels on route barangays',
                value: widget.showBarangayLabels,
              ),
              ListTile(
                leading: const Icon(Icons.zoom_in),
                title: const Text('Zoom readout'),
                subtitle: Text(
                  'Zoom / center readout on Home map (controlled by Admin page).',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: ValueListenableBuilder<bool>(
                  valueListenable: widget.showZoomReadout,
                  builder: (context, v, _) => Switch(
                    value: v,
                    onChanged: (nv) => widget.showZoomReadout.value = nv,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---- Live telemetry ----
        const Text('Live telemetry', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: ValueListenableBuilder<Map<String, String>>(
            valueListenable: widget.debugStats,
            builder: (context, stats, _) {
              if (stats.isEmpty) {
                return const ListTile(
                  title: Text('No telemetry yet'),
                  subtitle: Text('Open the Home map to start collecting stats.'),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: stats.entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key, style: const TextStyle(fontSize: 13)),
                          Text(e.value,
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    )).toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // ---- App info ----
        const Text('App info', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: const Column(
            children: [
              ListTile(
                title: Text('App name'),
                subtitle: Text('SeeRuta'),
                trailing: Text('org.research.seeruta',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
              Divider(height: 1),
              ListTile(
                title: Text('Version'),
                subtitle: Text('1.0.0'),
              ),
              Divider(height: 1),
              ListTile(
                title: Text('Map source'),
                subtitle: Text('assets/maps/cebu_city.mbtiles (OpenMapTiles 3.11)'),
              ),
              Divider(height: 1),
              ListTile(
                title: Text('Max zoom'),
                subtitle: Text('14'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required ValueNotifier<bool> value,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: value,
      builder: (context, v, _) => ListTile(
        leading: Icon(icon, size: 20),
        title: Text(title),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
        trailing: Switch(
          value: v,
          onChanged: (nv) => value.value = nv,
        ),
      ),
    );
  }
}
