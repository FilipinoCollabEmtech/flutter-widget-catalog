import 'dart:math' show pi, sin;

import 'package:flutter/material.dart';

import 'pages/admin_page.dart';
import 'pages/camera_demo_page.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'widgets/curved_nav_bar.dart';
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

/// App shell: tab content with animated page switches,
/// curved bottom bar + slide-in drawer for navigation.
/// The Admin tab stays hidden until the Konami code breaks it out.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  // Page indices: 0 = Home, 1 = Camera demo (placeholder),
  // 2 = Profile normally, Admin after Konami unlock replaces Profile.
  static const int _homePage = 0;
  static const int _profileSlot = 2;

  int _destIndex = _homePage;
  bool _adminUnlocked = false;
  /// Debug switch (Admin tab) that shows zoom info on the Home map.
  final ValueNotifier<bool> _showZoomInfo = ValueNotifier<bool>(false);
  /// Live debug stats shown on the Admin page (tile gate, cache, etc.).
  final ValueNotifier<Map<String, String>> _debugStats =
      ValueNotifier<Map<String, String>>({});
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
    _showZoomInfo.dispose();
    _debugStats.dispose();
    super.dispose();
  }

  void _onKonami() {
    if (_konami.completed) _startReveal();
  }

  /// Animated switch to a page (0 Home, 1 Admin, 2 Profile).
  /// While Admin is locked, tapping Home/Profile secretly feeds
  /// the Konami inputs B/A.
  void _goTo(int page) {
    // Re-tapping the active tab is a no-op: ignore it so stray
    // double-taps can't corrupt the secret sequence.
    if (!_adminUnlocked && page != _destIndex) {
      _konami.add(page == _homePage ? 'b' : 'a');
    }
    setState(() => _destIndex = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Secret unlocked: shake, pause, then Admin rises from below in a
  /// burst of gray debris, replacing Profile in the slot.
  Future<void> _startReveal() async {
    if (_revealing || _adminUnlocked) return;
    _revealing = true;
    _konami.reset();
    try {
      // Phase 1: shake, then stop.
      setState(() => _shaking = true);
      await _shakeController.forward(from: 0);
      setState(() => _shaking = false);
      await Future.delayed(const Duration(milliseconds: 200));
      // Phase 2: Admin rises like a zombie + gray debris, replacing Profile.
      setState(() => _rising = true);
      await _pageController.animateToPage(
        _profileSlot,
        duration: const Duration(milliseconds: 1400),
        curve: const ZombieLurch(),
      );
      // Phase 3: Admin broke free — restore its tab in the Profile slot.
      setState(() {
        _rising = false;
        _adminUnlocked = true;
        _destIndex = _profileSlot;
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

  /// Placeholder action for the temporary bottom-bar buttons.
  void _comingSoon(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label — coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavigationDrawer(
        onDestinationSelected: (i) {
          Navigator.pop(context);
          // Drawer entries: 0 = Home, 1 = Profile slot (Admin after Konami).
          _goTo(i == 0 ? _homePage : _profileSlot);
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
                  HomePage(
                    showZoomInfo: _showZoomInfo,
                    debugStats: _debugStats,
                  ),
                  const CameraDemoPage(),
                  _adminUnlocked
                      ? AdminPage(
                          showZoomInfo: _showZoomInfo,
                          debugStats: _debugStats,
                        )
                      : ProfilePage(konami: _konami),
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
      // Raised middle button: sits in the curve of the bottom bar.
      floatingActionButton: NavBarCenterButton(
        icon: Icons.directions,
        tooltip: 'Navigate',
        onPressed: () => _comingSoon('Navigate'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // Two buttons left, two right. All five are temporary for now.
      bottomNavigationBar: CurvedNavBar(
        left: [
          NavBarButton(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: 'Home',
            selected: _destIndex == _homePage,
            onTap: () => _goTo(_homePage),
          ),
          NavBarButton(
            icon: Icons.bookmark_border,
            selectedIcon: Icons.bookmark,
            label: 'Saved',
            selected: false,
            onTap: () => _comingSoon('Saved'),
          ),
        ],
        right: [
          // Admin replaces Profile in this slot after Konami unlock.
          _adminUnlocked
              ? NavBarButton(
                  icon: Icons.admin_panel_settings_outlined,
                  selectedIcon: Icons.admin_panel_settings,
                  label: 'Admin',
                  selected: _destIndex == _profileSlot,
                  visible: true,
                  onTap: () => _goTo(_profileSlot),
                )
              : NavBarButton(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: 'Profile',
                  selected: _destIndex == _profileSlot,
                  onTap: () => _goTo(_profileSlot),
                ),
        ],
      ),
    );
  }
}
