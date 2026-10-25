import 'dart:math' show pi, sin;

import 'package:flutter/material.dart';

import 'pages/demo_gallery.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'widgets/grave_particles.dart';
import 'widgets/konami.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Widget Catalog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// App shell: tab content with animated page switches and a curved
/// bottom bar (2 buttons, a raised center button, 2 buttons).
/// The Demo button stays hidden until the Konami code breaks it out.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  // Real PageView page: 0 = Home, 1 = Demo, 2 = Profile.
  int _pageIndex = 0;
  bool _demoUnlocked = false;
  bool _shaking = false;
  bool _rising = false;
  bool _revealing = false;

  late final PageController _pageController = PageController(initialPage: 0);
  late final KonamiController _konami = KonamiController();
  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void initState() {
    super.initState();
    _konami.addListener(_onKonami);
  }

  @override
  void dispose() {
    _konami.removeListener(_onKonami);
    _konami.dispose();
    _shakeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onKonami() {
    if (_konami.completed) _startReveal();
  }

  /// Animated switch to a page.
  /// While Demo is locked, tapping Home/Profile secretly feeds
  /// the Konami inputs B/A.
  void _goToPage(int page) {
    // Re-tapping the active tab is a no-op: ignore it so stray
    // double-taps can't corrupt the secret sequence.
    if (!_demoUnlocked && page != _pageIndex) {
      _konami.add(page == 0 ? 'b' : 'a');
    }
    setState(() => _pageIndex = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Secret unlocked: shake, pause, then Demo rises from below in a
  /// burst of gray debris before its button is restored.
  Future<void> _startReveal() async {
    if (_revealing || _demoUnlocked) return;
    _revealing = true;
    _konami.reset();
    try {
      // Phase 1: shake, then stop.
      setState(() => _shaking = true);
      await _shakeController.forward(from: 0);
      setState(() => _shaking = false);
      await Future.delayed(const Duration(milliseconds: 200));
      // Phase 2: Demo rises like a zombie + gray debris.
      setState(() => _rising = true);
      await _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 1400),
        curve: const ZombieLurch(),
      );
      // Phase 3: Demo broke free — restore its button.
      setState(() {
        _rising = false;
        _demoUnlocked = true;
        _pageIndex = 1;
      });
    } catch (e) {
      debugPrint('Reveal failed: $e');
      setState(() {
        _shaking = false;
        _rising = false;
      });
    }
    _revealing = false;
  }

  void _drawerExample(BuildContext context, String label) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — example only')),
    );
  }

  /// The two temporary buttons (and the raised center one) have no page yet.
  void _placeholder(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label — placeholder')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavigationDrawer(
        onDestinationSelected: (i) {
          Navigator.pop(context);
          // Drawer only lists Home (0) and Profile (1).
          _goToPage(i == 0 ? 0 : 2);
        },
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('NavigationDrawer',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const NavigationDrawerDestination(
              icon: Icon(Icons.home_outlined), label: Text('Home')),
          const NavigationDrawerDestination(
              icon: Icon(Icons.person_outline), label: Text('Profile')),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Examples',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () => _drawerExample(context, 'Settings'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            onTap: () => _drawerExample(context, 'Notifications'),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & feedback'),
            onTap: () => _drawerExample(context, 'Help & feedback'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: 'Widget Catalog',
                applicationVersion: '1.0.0',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _shakeController,
              builder: (_, child) {
                final t = _shakeController.value;
                final dx =
                    _shaking ? sin(t * pi * 10) * (1 - t) * 14 : 0.0;
                final dy =
                    _shaking ? sin(t * pi * 13 + 1.0) * (1 - t) * 10 : 0.0;
                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: child,
                );
              },
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const HomePage(),
                  const DemoGallery(),
                  ProfilePage(konami: _konami),
                ],
              ),
            ),
            if (_rising)
              const Positioned.fill(
                child: IgnorePointer(child: GraveParticles()),
              ),
          ],
        ),
      ),

      // Raised center button, docked into a curved notch in the bar.
      floatingActionButton: FloatingActionButton(
        onPressed: () => _placeholder('Navigate'),
        shape: const CircleBorder(),
        child: const Icon(Icons.navigation),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Layout: [Home] [Saved] (center notch) [Demo] [Profile]
      bottomNavigationBar: BottomAppBar(
        height: 72,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 8,
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Home',
                selected: _pageIndex == 0,
                onTap: () => _goToPage(0),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.bookmark_border,
                selectedIcon: Icons.bookmark,
                label: 'Saved',
                selected: false, // temporary: no page yet
                onTap: () => _placeholder('Saved'),
              ),
            ),
            // Room for the raised center button and its notch.
            const SizedBox(width: 72),
            Expanded(
              // Hidden (but keeps its slot) until the Konami code unlocks it.
              child: IgnorePointer(
                ignoring: !_demoUnlocked,
                child: AnimatedOpacity(
                  opacity: _demoUnlocked ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: _NavItem(
                    icon: Icons.widgets_outlined,
                    selectedIcon: Icons.widgets,
                    label: 'Demo',
                    selected: _pageIndex == 1,
                    onTap: () => _goToPage(1),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Profile',
                selected: _pageIndex == 2,
                onTap: () => _goToPage(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One icon + label button in the bottom bar.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return InkResponse(
      onTap: onTap,
      radius: 32,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Icon(selected ? selectedIcon : icon, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
