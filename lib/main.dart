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

  @override // what the sigma is an @override
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

/// App shell: tab content with animated page switches,
/// bottom toolbar + slide-in drawer for navigation.
/// The Demo tab stays hidden until the Konami code breaks it out.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  // Bottom-bar position. While Demo is locked: 0 = Home, 1 = Profile.
  int _destIndex = 0;
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

  /// Real page index for a bottom-bar destination.
  int _pageForDest(int dest) => _demoUnlocked ? dest : (dest == 0 ? 0 : 2);

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

  /// Animated switch to a bottom-bar destination.
  /// While Demo is locked, tapping Home/Profile secretly feeds
  /// the Konami inputs B/A.
  void _goTo(int dest) {
    // Re-tapping the active tab is a no-op: ignore it so stray
    // double-taps can't corrupt the secret sequence.
    if (!_demoUnlocked && dest != _destIndex) {
      _konami.add(dest == 0 ? 'b' : 'a');
    }
    setState(() => _destIndex = dest);
    _pageController.animateToPage(
      _pageForDest(dest),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Secret unlocked: shake, pause, then Demo rises from below in a
  /// burst of gray debris before its tab is restored.
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
      // Phase 3: Demo broke free — restore its tab.
      setState(() {
        _rising = false;
        _demoUnlocked = true;
        _destIndex = 1;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavigationDrawer(
        onDestinationSelected: (i) {
          Navigator.pop(context);
          _goTo(i);
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _destIndex,
        onDestinationSelected: _goTo,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          if (_demoUnlocked)
            const NavigationDestination(
              icon: Icon(Icons.widgets_outlined),
              selectedIcon: Icon(Icons.widgets),
              label: 'Demo',
            ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
