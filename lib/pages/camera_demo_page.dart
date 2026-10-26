import 'package:flutter/material.dart';

/// Camera demo placeholder page.
/// Sits in the slot where the Admin page used to appear.
/// Tapping the button shows a "coming soon" snackbar until
/// real camera functionality is wired up.
class CameraDemoPage extends StatelessWidget {
  const CameraDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt, size: 96, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Camera Demo',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Coming soon',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Camera demo — coming soon')),
            ),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Open Camera (demo)'),
          ),
        ],
      ),
    );
  }
}
