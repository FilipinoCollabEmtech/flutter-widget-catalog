import 'package:flutter/material.dart';

/// Placeholder for the Profile tab — fill in later.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 48),
          SizedBox(height: 8),
          Text('Profile — empty for now'),
        ],
      ),
    );
  }
}
