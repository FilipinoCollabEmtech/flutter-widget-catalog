import 'package:flutter/material.dart';

/// Admin tab: debug switches. Currently one toggle that shows the map's
/// zoom level (and center) in the top right of the Home tab.
class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.showZoomInfo});

  final ValueNotifier<bool> showZoomInfo;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Admin', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Card(
          child: ValueListenableBuilder<bool>(
            valueListenable: showZoomInfo,
            builder: (context, value, _) => SwitchListTile(
              secondary: const Icon(Icons.zoom_in),
              title: const Text('Show zoom level'),
              subtitle: const Text(
                'Shows the zoom level and map center in the top right of the Home tab.',
              ),
              value: value,
              onChanged: (v) => showZoomInfo.value = v,
            ),
          ),
        ),
      ],
    );
  }
}
