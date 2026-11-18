import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings page, opened from the burger menu dropdown on Home.
///
/// Currently holds the Accessibility section with the SeeRuta Assistant
/// toggle. The Assistant itself is not built yet: turning it on shows a
/// temporary notification, and the choice is persisted with
/// shared_preferences so it survives restarts.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _assistantPrefKey = 'seeRutaAssistantEnabled';

  SharedPreferences? _prefs;
  bool _assistantEnabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _assistantEnabled = prefs.getBool(_assistantPrefKey) ?? false;
      _loaded = true;
    });
  }

  Future<void> _toggleAssistant(bool value) async {
    setState(() => _assistantEnabled = value);
    await _prefs?.setBool(_assistantPrefKey, value);
    // Placeholder feedback until the Assistant itself exists.
    if (value && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('SeeRuta Assistant enabled')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Accessibility', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              secondary: const Icon(Icons.record_voice_over_outlined),
              title: const Text('SeeRuta Assistant'),
              subtitle: const Text('Preview — coming soon'),
              value: _assistantEnabled,
              onChanged: _loaded ? _toggleAssistant : null,
            ),
          ),
        ],
      ),
    );
  }
}
