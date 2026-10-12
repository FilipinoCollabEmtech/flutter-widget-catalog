import 'package:flutter/material.dart';

/// Home tab: burger menu row on top, search bar below it.
class HomePage extends StatelessWidget {
  final VoidCallback onMenuPressed;

  const HomePage({super.key, required this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Open menu',
                onPressed: onMenuPressed,
              ),
              const Text('Home',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings — example only')),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: SearchBar(
            hintText: 'Search...',
            leading: Icon(Icons.search),
          ),
        ),
        const Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_outlined, size: 48),
                SizedBox(height: 8),
                Text('Home — empty for now'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
