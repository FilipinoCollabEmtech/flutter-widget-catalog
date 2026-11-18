import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/assistant_service.dart';

/// Settings page, opened from the burger menu dropdown on Home.
///
/// Holds the Accessibility section with the SeeRuta Assistant toggle, which
/// shows the mic button on Home. Turning the toggle on speaks a confirmation
/// through the speaker (audio-first for blind users); the choice is persisted
/// with shared_preferences so it survives restarts.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SharedPreferences? _prefs;
  bool _assistantEnabled = false;
  bool _loaded = false;
  FlutterTts? _tts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tts?.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _assistantEnabled =
          prefs.getBool(AssistantService.assistantPrefKey) ?? false;
      _loaded = true;
    });
  }

  /// Lazily builds the TTS engine used for toggle confirmations, mirroring
  /// the Assistant's voice settings.
  Future<FlutterTts?> _ensureTts() async {
    if (_tts != null) return _tts;
    try {
      final tts = FlutterTts();
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(AssistantService.speechRate);
      _tts = tts;
    } catch (_) {
      _tts = null; // TTS unavailable: the SnackBar still confirms.
    }
    return _tts;
  }

  Future<void> _toggleAssistant(bool value) async {
    setState(() => _assistantEnabled = value);
    await _prefs?.setBool(AssistantService.assistantPrefKey, value);
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'SeeRuta Assistant enabled. Find the mic button on Home.'
                  : 'SeeRuta Assistant disabled.',
            ),
          ),
        );
    }
    // Audio-first: confirm out loud so blind users know the toggle took.
    final tts = await _ensureTts();
    await tts?.speak(
      value ? 'SeeRuta Assistant enabled' : 'SeeRuta Assistant disabled',
    );
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
              subtitle: const Text('Voice commands on the Home mic — offline'),
              value: _assistantEnabled,
              onChanged: _loaded ? _toggleAssistant : null,
            ),
          ),
        ],
      ),
    );
  }
}
