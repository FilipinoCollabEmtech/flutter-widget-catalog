import 'package:flutter/material.dart';

import '../widgets/konami.dart';

class ProfilePage extends StatefulWidget {
  final KonamiController konami;

  const ProfilePage({super.key, required this.konami});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  void _loadData() {
    setState(() => _loading = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  /// Round gamepad-style button (design only, does nothing).
  Widget _padButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 56,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 160,
              child: LinearProgressIndicator(),
            ),
            SizedBox(height: 16),
            Text('Loading profile...'),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_2_outlined, size: 48),
          const SizedBox(height: 8),
          const Text(
            'John Doe',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _loadData,
            child: const Text('Reload'),
          ),
          const SizedBox(height: 32),
          // 5-button cluster: up / left-center-right / down
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 56),
              const SizedBox(width: 8),
              _padButton(Icons.arrow_upward,
                  () => widget.konami.add('up')),
              const SizedBox(width: 8),
              const SizedBox(width: 56),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _padButton(Icons.arrow_back,
                  () => widget.konami.add('left')),
              const SizedBox(width: 8),
              _padButton(Icons.circle,
                  () => widget.konami.add('start')),
              const SizedBox(width: 8),
              _padButton(Icons.arrow_forward,
                  () => widget.konami.add('right')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 56),
              const SizedBox(width: 8),
              _padButton(Icons.arrow_downward,
                  () => widget.konami.add('down')),
              const SizedBox(width: 8),
              const SizedBox(width: 56),
            ],
          ),
        ],
      ),
    );
  }
}