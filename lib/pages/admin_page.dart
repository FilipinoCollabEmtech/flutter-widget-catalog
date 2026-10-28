import 'package:flutter/material.dart';

/// Admin tab: debug switches and live telemetry.
/// Shows zoom level toggle, tile gate stats, cache info, and app version.
class AdminPage extends StatelessWidget {
  const AdminPage({
    super.key,
    required this.showZoomInfo,
    required this.debugStats,
  });

  /// Toggles the zoom/center readout overlay on the Home map.
  final ValueNotifier<bool> showZoomInfo;

  /// Live debug stats (tile gate limit/active/queued, cache sizes, etc.).
  final ValueNotifier<Map<String, String>> debugStats;

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
                valueListenable: showZoomInfo,
                builder: (context, value, _) => SwitchListTile(
                  secondary: const Icon(Icons.zoom_in),
                  title: const Text('Show zoom level'),
                  subtitle: const Text(
                    'Shows zoom level and map center in the top right of the Home tab.',
                  ),
                  value: value,
                  onChanged: (v) => showZoomInfo.value = v,
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
            valueListenable: debugStats,
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
}
