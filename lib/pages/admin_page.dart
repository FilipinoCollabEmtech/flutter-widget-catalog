import 'package:flutter/material.dart';

import '../pages/mbtiles_vector_tile_provider.dart';

/// Admin tab: debug switches and live telemetry.
///
/// Shows zoom level toggle, tile gate stats, tile generation tracking,
/// discarded tile count, and app version. When the "Debug telemetry" switch
/// is on, every tile read, generation bump, and discard is logged to the
/// console so you can see exactly what is causing pinch-and-zoom lag.
class AdminPage extends StatefulWidget {
  const AdminPage({
    super.key,
    required this.showZoomInfo,
    required this.debugStats,
  });

  /// Toggles the zoom/center readout overlay on the Home map.
  final ValueNotifier<bool> showZoomInfo;

  /// Live debug stats (tile gate limit/active/queued, tile generation,
  /// discarded tiles, pending tiles, pinch mode, etc.).
  final ValueNotifier<Map<String, String>> debugStats;

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

        // ---- Debug telemetry explanations ----
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Debug telemetry', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Toggle "Debug telemetry" to log every tile read, generation '
                    'bump, and discard to the console for diagnosing '
                    'pinch-and-zoom lag.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Tile generation'),
                subtitle: Text(
                  'Increments on every pinch gesture. Stale tile reads are '
                      'discarded.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              ListTile(
                title: const Text('Discarded tiles'),
                subtitle: Text(
                  'Tile reads thrown away because a newer pinch gesture '
                      'invalidated them.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              ListTile(
                title: const Text('Pending tiles'),
                subtitle: Text(
                  'Tile reads currently waiting on the worker isolate.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              ListTile(
                title: const Text('Pinch active'),
                subtitle: Text(
                  'True while the user is actively pinching. Tile reads are '
                      'debounced to 100 ms and gated to 1 concurrent load.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
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
}
