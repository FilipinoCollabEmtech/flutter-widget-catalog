import 'package:flutter/material.dart';

/// Home tab: search bar with a circular burger button on its right.
/// Tapping the button plays a press animation, morphs the icon,
/// and expands a little menu panel underneath.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  bool _pressed = false;
  late final AnimationController _icon = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  @override
  void dispose() {
    _icon.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _icon.forward();
    } else {
      _icon.reverse();
    }
  }

  void _example(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — example only')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: SearchBar(
                  hintText: 'Search...',
                  leading: Icon(Icons.search),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                onTap: _toggle,
                child: AnimatedScale(
                  scale: _pressed ? 0.85 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surfaceContainerHigh,
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 4,
                          offset: Offset(0, 2),
                          color: Colors.black12,
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedIcon(
                        icon: AnimatedIcons.menu_close,
                        progress: _icon,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _open
                ? Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.settings_outlined),
                          title: const Text('Settings'),
                          onTap: () => _example('Settings'),
                        ),
                        ListTile(
                          leading:
                              const Icon(Icons.notifications_outlined),
                          title: const Text('Notifications'),
                          onTap: () => _example('Notifications'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.help_outline),
                          title: const Text('Help & feedback'),
                          onTap: () => _example('Help & feedback'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('About'),
                          onTap: () => showAboutDialog(
                            context: context,
                            applicationName: 'Widget Catalog',
                            applicationVersion: '1.0.0',
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        const Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_outlined, size: 48),
                SizedBox(height: 8),
                Text('Put like fake cebu map here maybe png lol'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
