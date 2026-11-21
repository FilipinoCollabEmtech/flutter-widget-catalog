import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'code_scan_page.dart';

import '../services/ocr_settings.dart';
import '../services/voice_log.dart';
import 'researcher_page.dart';

/// Admin tab: debug switches and live telemetry for the MapLibre (GPU) map.
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
    required this.onRebuildStyle,
    required this.onRefreshStats,
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

  /// Rebuilds the MapLibre style.json and re-loads the map (Admin: "Force reload").
  final VoidCallback onRebuildStyle;

  /// Re-computes and pushes fresh debug telemetry to [debugStats].
  final VoidCallback onRefreshStats;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final TextEditingController _appsScriptUrlController = TextEditingController();
  String? _appsScriptStatus;

  @override
  void initState() {
    super.initState();
    // Load persisted transcripts for the Voice Recognition section.
    unawaited(VoiceLog.instance.ensureLoaded());
  }

  @override
  void dispose() {
    _appsScriptUrlController.dispose();
    super.dispose();
  }

  Future<void> _sendToAppsScript() async {
    final url = _appsScriptUrlController.text.trim();
    if (url.isEmpty) {
      setState(() => _appsScriptStatus = 'Error: URL is empty.');
      return;
    }
    setState(() => _appsScriptStatus = 'Sending…');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: '{"test": true, "message": "SeeRuta admin ping"}',
      );
      if (response.statusCode == 200) {
        setState(() => _appsScriptStatus = 'Sent successfully (${response.statusCode}).');
      } else {
        setState(() => _appsScriptStatus = 'Error: HTTP ${response.statusCode}.');
      }
    } catch (e) {
      setState(() => _appsScriptStatus = 'Error: $e');
    }
  }

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
              ListTile(
                leading: const Icon(Icons.build),
                title: const Text('Rebuild map style'),
                subtitle: const Text(
                  'Re-generates style.json from assets/maps/cebu_city.mbtiles '
                      'and re-loads the MapLibre map. Use after editing the style.',
                ),
                onTap: widget.onRebuildStyle,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Refresh stats'),
                subtitle: const Text(
                  'Re-computes debug telemetry (renderer, style, zoom, center).',
                ),
                onTap: widget.onRefreshStats,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---- OCR engine ----
        const Text('OCR engine', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: ValueListenableBuilder<OcrEngine>(
            valueListenable: OcrSettings.engine,
            builder: (context, engine, _) => Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.document_scanner),
                  title: const Text('Use PP-OCRv6 (on-device)'),
                  subtitle: Text(
                    engine == OcrEngine.ppocr
                        ? 'Active: ${engine.label}. Recognizes the reticle crop only.'
                        : 'Active: ${engine.label}. Switch on to test PP-OCR on real signs.',
                  ),
                  value: engine == OcrEngine.ppocr,
                  onChanged: (v) => OcrSettings.engine.value =
                      v ? OcrEngine.ppocr : OcrEngine.mlkit,
                ),
                const Divider(height: 1),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.info_outline),
                  title: Text(engine.label),
                  subtitle: const Text(
                    'PP-OCRv6 small (ONNX, 12 MB) runs on the centre of the '
                    'frame — the reticle is the crop, so no detector is used. '
                    'Head pruned to A-Z a-z 0-9: it cannot emit anything else. '
                    'Still stock weights, not yet fine-tuned on jeepneys.',
                  ),
                ),
              ],
            ),
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
                subtitle: 'Roads, landuse, buildings, labels (MBTiles via MapLibre)',
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
                subtitle: 'Blue line between route waypoints (Barangays tab)',
                value: widget.showRoutePolyline,
              ),
              _buildToggle(
                icon: Icons.map,
                title: 'Barangay polygons',
                subtitle: 'Colored territory polygons (Barangays tab)',
                value: widget.showBarangayPolygons,
              ),
              _buildToggle(
                icon: Icons.label,
                title: 'Barangay labels',
                subtitle: 'Name labels on route barangays (Barangays tab)',
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

        // ---- Voice Recognition ----
        Row(
          children: [
            const Expanded(
              child: Text('Voice Recognition',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ValueListenableBuilder<List<VoiceLogEntry>>(
              valueListenable: VoiceLog.instance.entries,
              builder: (context, entries, _) => TextButton.icon(
                onPressed:
                    entries.isEmpty ? null : () => VoiceLog.instance.clear(),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Clear'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Every finished capture, newest first — including ones that heard '
          'nothing, with mic level and duration so a silent capture can be '
          'diagnosed here. Stored on this device only '
          '(max ${VoiceLog.maxEntries}).',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        Card(
          child: ValueListenableBuilder<List<VoiceLogEntry>>(
            valueListenable: VoiceLog.instance.entries,
            builder: (context, entries, _) {
              if (entries.isEmpty) {
                return const ListTile(
                  leading: Icon(Icons.mic_none),
                  title: Text('No voice captures yet'),
                  subtitle: Text(
                    'Enable the Assistant (Settings > Accessibility) and use '
                    'the Home mic. Each tap is logged here, even when no '
                    'speech is recognized.',
                  ),
                );
              }
              final scheme = Theme.of(context).colorScheme;
              return Column(
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      dense: true,
                      leading: Icon(
                        entries[i].heard ? Icons.mic : Icons.mic_off,
                        size: 20,
                        color: entries[i].heard ? null : scheme.outline,
                      ),
                      title: Text(
                        entries[i].heard
                            ? entries[i].text
                            : 'Nothing recognized',
                        style: entries[i].heard
                            ? null
                            : TextStyle(
                                fontStyle: FontStyle.italic,
                                color: scheme.outline,
                              ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_formatTimestamp(entries[i].time)} · '
                            '${_formatStats(entries[i].stats)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          if (entries[i].stats.error != null)
                            Text(
                              'Error: ${entries[i].stats.error}',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.error,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // ---- Researcher tools ----
        const Text('Researcher tools', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.route),
                title: const Text('Record jeepney route'),
                subtitle: const Text(
                  'Select a jeepney code and record GPS movement to build the '
                  'route polyline for jeepney_routes.json.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ResearcherPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.document_scanner),
                title: const Text('Scan jeepney code'),
                subtitle: const Text(
                  'Use the camera to scan a jeepney code and match it to a route.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CodeScanPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---- Apps Script integration ----
        const Text('Apps Script integration', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Send recorded route data to a Google Apps Script endpoint '
                  'that writes to a spreadsheet.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _appsScriptUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Apps Script URL',
                    hintText: 'https://script.google.com/macros/s/.../exec',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _sendToAppsScript,
                  icon: const Icon(Icons.send),
                  label: const Text('Send test payload'),
                ),
                if (_appsScriptStatus != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _appsScriptStatus!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _appsScriptStatus!.startsWith('Error')
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ],
              ],
            ),
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
              Divider(height: 1),
              ListTile(
                title: Text('Renderer'),
                subtitle: Text('MapLibre GL (native, GPU)'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatTimestamp(DateTime time) {
    final t = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  /// One compact line that explains both a silent capture and a slow one:
  /// how long the mic ran, how much was voiced, the silence tail and decoder
  /// time after the user stopped, how loud it got, and whether the fallback
  /// decoder ran.
  static String _formatStats(VoiceCaptureStats stats) {
    if (!stats.hasAudio) return 'No audio from microphone';
    final peak = stats.peak <= 0
        ? 'peak 0%'
        : 'peak ${(stats.peak * 100).toStringAsFixed(1)}%';
    final tail = stats.tailSeconds > 0
        ? ' · tail ${stats.tailSeconds.toStringAsFixed(1)} s'
        : '';
    final decode = stats.decodeMs > 0
        ? ' · decode ${(stats.decodeMs / 1000).toStringAsFixed(1)} s'
        : '';
    final fallback = stats.retried ? ' · full-buffer decode' : '';
    return '${stats.seconds.toStringAsFixed(1)} s · '
        '${stats.voicedSeconds.toStringAsFixed(1)} s voiced'
        '$tail$decode · $peak$fallback';
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
