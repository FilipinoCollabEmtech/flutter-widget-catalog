import 'dart:math' show pi, sin;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/route.dart';
import 'pages/admin_page.dart';
import 'pages/barangay_route_page.dart';
import 'pages/code_scan_page.dart';
import 'pages/home_page.dart';
import 'pages/loading_screen.dart';
import 'pages/offline_map_assets.dart';
import 'pages/profile_page.dart';
import 'pages/researcher_page.dart';
import 'services/route_focus.dart';
import 'services/route_loader.dart';
import 'services/route_planner.dart';
import 'widgets/grave_particles.dart';
import 'widgets/konami.dart';
import 'widgets/pill_nav_bar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SeeRuta',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const StartupScreen(),
    );
  }
}

/// Startup gate: keeps the static [LoadingScreen] on screen while the route
/// catalogue loads and the permission prompts are answered. The shell is
/// mounted behind the screen as soon as the catalogue is ready, so the map can
/// initialise out of sight; the screen stays for at least two seconds, then
/// fades away over the ready map.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  /// The permissions the app actually uses: the map's user location, the
  /// scanner's camera and the Assistant's microphone. A denial is not fatal —
  /// each feature checks (and can ask) again when it is used.
  static const List<Permission> _startupPermissions = [
    Permission.locationWhenInUse,
    Permission.camera,
    Permission.microphone,
  ];

  /// Minimum time the white screen stays up, counted from the first frame.
  /// It overlaps the permission prompts; once those are done it is the window
  /// in which the map behind the screen finishes its first render.
  static const Duration _minimumSplash = Duration(seconds: 2);

  /// Fade-out over the map once the minimum is over and the app is ready.
  static const Duration _splashFade = Duration(milliseconds: 350);

  RouteState? _routes;
  bool _splashDone = false;
  bool _splashRemoved = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Paint the white screen before the first system dialog covers it.
    await WidgetsBinding.instance.endOfFrame;
    final minimumSplash = Future<void>.delayed(_minimumSplash);
    // Load the catalogue and prepare the offline map (first run copies the
    // MBTiles) while the prompts are up: everything finishes behind the same
    // screen.
    final routesFuture = RouteLoader.load();
    final mapFuture = _prepareMapAssets();
    final permissionsFuture = _askStartupPermissions();

    List<JeepneyRoute> routes;
    try {
      routes = await routesFuture;
    } catch (error) {
      // Never leave the user on the loading screen because of the database.
      debugPrint('Route catalogue failed to load: $error');
      routes = const [];
    }
    if (!mounted) return;
    // Mount the shell now rather than after the splash: HomePage builds the
    // MapLibre view and loads the style behind the white screen.
    setState(() => _routes = RouteState(RoutePlanner(routes)));

    await permissionsFuture;
    await mapFuture;
    await minimumSplash;
    if (!mounted) return;
    setState(() => _splashDone = true);
  }

  /// Copies the MBTiles/glyphs and writes style.json so the home page's map
  /// has nothing left to do when it opens.
  Future<void> _prepareMapAssets() async {
    try {
      await OfflineMapAssets.prepare();
    } catch (error) {
      // HomePage retries and shows the error on the map itself.
      debugPrint('Offline map preparation failed at startup: $error');
    }
  }

  Future<void> _askStartupPermissions() async {
    for (final permission in _startupPermissions) {
      try {
        final status = await permission.request();
        debugPrint('Startup permission $permission: $status');
      } catch (error) {
        // A platform that cannot answer (or a plugin failure) must not leave
        // the user stuck on the loading screen.
        debugPrint('Startup permission $permission failed: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final routes = _routes;
    if (routes == null) return const LoadingScreen();
    // HomeScreen keeps the same slot in the stack while the splash is up, so
    // revealing it does not rebuild the map that is already alive underneath.
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: !_splashDone,
          child: HomeScreen(routes: routes),
        ),
        if (!_splashRemoved)
          // While the splash is solid it absorbs taps meant for the shell;
          // once it starts fading, taps fall through to the map being revealed.
          IgnorePointer(
            ignoring: _splashDone,
            child: AbsorbPointer(
              child: AnimatedOpacity(
                opacity: _splashDone ? 0 : 1,
                duration: _splashFade,
                curve: Curves.easeOut,
                onEnd: _onSplashFadeEnd,
                child: const LoadingScreen(),
              ),
            ),
          ),
      ],
    );
  }

  /// Removes the splash once it has faded out completely.
  void _onSplashFadeEnd() {
    if (!_splashDone || !mounted) return;
    setState(() => _splashRemoved = true);
  }
}

/// App shell: tab content with animated page switches,
/// floating bottom bar + slide-in drawer for navigation.
/// The Admin tab stays hidden until the Konami code breaks it out.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.routes});

  /// Catalogue loaded behind the loading screen in [StartupScreen].
  final RouteState routes;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  // Page indices: 0 = Home, 1 = Camera demo (placeholder),
  // 2 = Profile normally, Admin after Konami unlock replaces Profile,
  // 3 = Barangay route.
  static const int _homePage = 0;
  static const int _cameraDemoPage = 1;
  static const int _profileSlot = 2;
  static const int _barangayPage = 3;

  int _destIndex = _homePage;
  bool _adminUnlocked = false;
  /// Debug switch (Admin tab) that shows zoom info on the Home map.
  final ValueNotifier<bool> _showZoomInfo = ValueNotifier<bool>(false);
  /// Live debug stats shown on the Admin page (tile gate, cache, etc.).
  final ValueNotifier<Map<String, String>> _debugStats =
      ValueNotifier<Map<String, String>>({});
  /// Bumped when the Admin panel requests a map style rebuild; HomePage listens.
  final ValueNotifier<int> _rebuildStyleKey = ValueNotifier<int>(0);
  /// Bumped by the bar's locate button; HomePage centres on the user.
  final ValueNotifier<int> _locateRequests = ValueNotifier<int>(0);

  /// Individual layer visibility toggles (Admin -> each page).
  final ValueNotifier<bool> _showVectorTiles = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _showCebuBoundary = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _showCebuArrow = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _showUserLocation = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _showRoutePolyline = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _showBarangayPolygons = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _showBarangayLabels = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _showZoomReadout = ValueNotifier<bool>(false);

  bool _shaking = false;
  bool _rising = false;
  bool _revealing = false;

  /// Drives the tab switch: at 0 the incoming page is just offscreen, at 1 it
  /// covers the screen and the outgoing page is gone.
  late final AnimationController _slideController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );
  /// Page the last switch landed on.
  int _currentPage = _homePage;
  /// Page sliding out mid-switch; null once the switch has settled.
  int? _leavingPage;
  /// Whether the incoming page comes from the right (moving forward in
  /// [_tabOrder]).
  bool _forward = true;
  /// Pages currently in the tree: the map page, which is always kept mounted,
  /// plus whichever page is on screen or sliding. Other pages are dropped once
  /// they have slid out, so reopening one builds it fresh instead of keeping
  /// its widgets (camera, lists) alive in the background.
  final Set<int> _builtPages = {_homePage};

  /// Left-to-right order of the bar. It is not the page index order: Barangays
  /// (3) sits second in the bar while Camera (1) sits fourth, and the slide
  /// direction has to follow what the user sees.
  static const List<int> _tabOrder = [
    _homePage,
    _barangayPage,
    _cameraDemoPage,
    _profileSlot,
  ];

  static int _orderOf(int page) => _tabOrder.indexOf(page);

  late final KonamiController _konami = KonamiController();
  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void initState() {
    super.initState();
    _konami.addListener(_onKonami);
    RouteFocus.tabRequest.addListener(_onTabRequest);
  }

  /// The scanner asks for the home tab after it announces a route.
  void _onTabRequest() {
    final page = RouteFocus.tabRequest.value;
    if (page == null || !mounted) return;
    RouteFocus.tabRequest.value = null;
    _goTo(page);
  }

  @override
  void dispose() {
    _konami.removeListener(_onKonami);
    RouteFocus.tabRequest.removeListener(_onTabRequest);
    _konami.dispose();
    _shakeController.dispose();
    _slideController.dispose();
    _showZoomInfo.dispose();
    _debugStats.dispose();
    _showVectorTiles.dispose();
    _showCebuBoundary.dispose();
    _showCebuArrow.dispose();
    _showUserLocation.dispose();
    _showRoutePolyline.dispose();
    _showBarangayPolygons.dispose();
    _showBarangayLabels.dispose();
    _showZoomReadout.dispose();
    _rebuildStyleKey.dispose();
    _locateRequests.dispose();
    super.dispose();
  }

  void _onKonami() {
    if (_konami.completed) _startReveal();
  }

  /// Animated switch to a page (0 Home, 1 Camera, 2 Profile/Admin,
  /// 3 Barangays).
  /// While Admin is locked, tapping Home/Profile secretly feeds
  /// the Konami inputs B/A.
  void _goTo(int page) {
    // Re-tapping the active tab is a no-op: ignore it so stray
    // double-taps can't corrupt the secret sequence.
    if (!_adminUnlocked && page != _destIndex) {
      _konami.add(page == _homePage ? 'b' : 'a');
    }
    if (page == _destIndex) return;
    _slideTo(page);
  }

  /// Slides [page] in from the right when its tab sits to the right of the
  /// current one, and from the left when it sits to the left, pushing the
  /// current page out the opposite way. Only those two pages take part, so a
  /// jump from Home to Profile no longer builds the pages in between (the
  /// camera used to start up on the way past it).
  Future<void> _slideTo(
    int page, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) async {
    if (page == _destIndex && _leavingPage == null) return;
    // Tapped while a switch is still running: land that switch first, then
    // start the new one from the page that is already fully open.
    if (_leavingPage != null) {
      _slideController.stop();
      _currentPage = _destIndex;
      _leavingPage = null;
    }
    final from = _currentPage;
    if (page == from) return;
    _builtPages.add(page);
    setState(() {
      _leavingPage = from;
      _destIndex = page;
      _forward = _orderOf(page) > _orderOf(from);
    });
    _slideController.duration = duration;
    await _slideController.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _currentPage = page;
      _leavingPage = null;
      // Only the map page lives on. The page that just slid out — and any page
      // left behind by an interrupted switch — is disposed here, offscreen, so
      // its next visit starts from a clean state.
      _builtPages.removeWhere((p) => p != _homePage && p != page);
    });
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
      await _slideTo(
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

  /// The map runs behind the floating bar, other pages must stay above it.
  Widget _aboveBar(Widget page) => Builder(
        builder: (context) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
          child: page,
        ),
      );

  /// Builds a page by index. Pages are only constructed when opened; only the
  /// map page stays in [_builtPages] after it has been shown.
  Widget _pageAt(int index) {
    switch (index) {
      case _homePage:
        return HomePage(
          showZoomInfo: _showZoomInfo,
          debugStats: _debugStats,
          showVectorTiles: _showVectorTiles,
          showCebuBoundary: _showCebuBoundary,
          showCebuArrow: _showCebuArrow,
          showUserLocation: _showUserLocation,
          showZoomReadout: _showZoomReadout,
          rebuildStyleKey: _rebuildStyleKey,
          locateRequest: _locateRequests,
          routes: widget.routes,
        );
      case _cameraDemoPage:
        return _aboveBar(const CodeScanPage());
      case _barangayPage:
        return _aboveBar(
          BarangayRoutePage(
            showBarangayPolygons: _showBarangayPolygons,
            showBarangayLabels: _showBarangayLabels,
            showRoutePolyline: _showRoutePolyline,
          ),
        );
      default:
        return _aboveBar(
          _adminUnlocked
              ? AdminPage(
                  showZoomInfo: _showZoomInfo,
                  debugStats: _debugStats,
                  showVectorTiles: _showVectorTiles,
                  showCebuBoundary: _showCebuBoundary,
                  showCebuArrow: _showCebuArrow,
                  showUserLocation: _showUserLocation,
                  showRoutePolyline: _showRoutePolyline,
                  showBarangayPolygons: _showBarangayPolygons,
                  showBarangayLabels: _showBarangayLabels,
                  showZoomReadout: _showZoomReadout,
                  onRebuildStyle: () => _rebuildStyleKey.value++,
                  onRefreshStats: () {
                    _debugStats.value = {
                      'Renderer': 'MapLibre (native)',
                      'Style': 'assets/maps/cebu_city.mbtiles',
                      'Max zoom': '14',
                      'Glyphs': 'NotoSans Regular/Medium/Italic',
                    };
                  },
                )
              : ProfilePage(konami: _konami),
        );
    }
  }

  /// One page of the stack, shifted sideways without being laid out again.
  Widget _pageLayer(int index, Offset offset, {required bool interactive}) {
    return FractionalTranslation(
      // Stable key: Stack children are matched by position, and the layer
      // order changes while a switch runs (parked, outgoing, incoming). Without
      // the key the always-mounted map page would be torn down and rebuilt
      // whenever it changed slot, losing the map on the way back to Home.
      key: ValueKey<int>(index),
      translation: offset,
      child: IgnorePointer(
        ignoring: !interactive,
        child: TickerMode(
          enabled: interactive,
          child: _pageAt(index),
        ),
      ),
    );
  }

  /// The two pages involved in a switch (outgoing under, incoming over) plus
  /// any other live page parked fully offscreen — normally only the map while
  /// another tab is open.
  Widget _buildPageStack() {
    final t = _slideController.value;
    final direction = _forward ? 1.0 : -1.0;
    final incoming = _destIndex;
    final outgoing = _leavingPage;
    final layers = <Widget>[
      for (final index in _builtPages)
        if (index != incoming && index != outgoing)
          _pageLayer(index, Offset(direction * 2, 0), interactive: false),
      if (outgoing != null)
        _pageLayer(outgoing, Offset(-direction * t, 0), interactive: true),
      _pageLayer(incoming, Offset(direction * (1 - t), 0), interactive: true),
    ];
    return Stack(fit: StackFit.expand, children: layers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: true, // let the map flow behind the floating bar
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
            leading: const Icon(Icons.science_outlined),
            title: const Text('Researcher (record route)'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ResearcherPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: 'SeeRuta',
                applicationVersion: '1.0.0',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
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
              child: AnimatedBuilder(
                animation: _slideController,
                builder: (_, _) => _buildPageStack(),
              ),
            ),
            if (_rising)
              const Positioned.fill(
                child: IgnorePointer(child: GraveParticles()),
              ),
          ],
        ),
      ),
      // Floating rounded bar: two buttons, raised middle button, two buttons.
      bottomNavigationBar: PillNavBar(
        // brightness: Brightness.dark, // uncomment to preview the dark colors
        center: NavBarCenterButton(
          icon: Icons.my_location,
          tooltip: 'Show my location',
          onPressed: () {
            // The user dot only exists on the Home map, so reveal it first.
            // Use _slideTo directly: this must not feed the Konami sequence.
            if (_destIndex != _homePage) _slideTo(_homePage);
            _locateRequests.value++;
          },
        ),
        left: [
          NavBarButton(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Home',
            selected: _destIndex == _homePage,
            onTap: () => _goTo(_homePage),
          ),
          NavBarButton(
            icon: Icons.map,
            selectedIcon: Icons.map_rounded,
            label: 'Barangays',
            selected: _destIndex == _barangayPage,
            onTap: () => _goTo(_barangayPage),
          ),
        ],
        right: [
          NavBarButton(
            icon: Icons.photo_camera_outlined,
            selectedIcon: Icons.photo_camera_rounded,
            label: 'Camera',
            selected: _destIndex == _cameraDemoPage,
            onTap: () => _goTo(_cameraDemoPage),
          ),
          // Admin replaces Profile in this slot after the Konami unlock.
          _adminUnlocked
              ? NavBarButton(
                  icon: Icons.admin_panel_settings_outlined,
                  selectedIcon: Icons.admin_panel_settings,
                  label: 'Admin',
                  selected: _destIndex == _profileSlot,
                  onTap: () => _goTo(_profileSlot),
                )
              : NavBarButton(
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: 'Profile',
                  selected: _destIndex == _profileSlot,
                  onTap: () => _goTo(_profileSlot),
                ),
        ],
      ),
    );
  }
}
