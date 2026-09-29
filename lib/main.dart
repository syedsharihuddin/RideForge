import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'screens/tracking_screen.dart';
import 'screens/history_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/ride_details_screen.dart';

import 'services/database_service.dart';
import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'services/automatic_tracking_service.dart';
import 'config/map_style_config.dart';
import 'services/location_service.dart';
import 'widgets/ride_map_widget.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const BikeTrackerApp());

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    NotificationService.instance.onNotificationTap = _handleNotificationTap;

    await NotificationService.instance.initialize();
  });
}

Future<void> _handleNotificationTap(String? payload) async {
  if (payload == null || payload.isEmpty) {
    return;
  }

  final rideId = int.tryParse(payload);

  if (rideId == null) {
    return;
  }

  final ride = await DatabaseService.instance.getRideById(rideId);

  if (ride == null) {
    return;
  }

  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (_) => RideDetailsScreen(ride: ride)),
  );
}

class BikeTrackerApp extends StatefulWidget {
  const BikeTrackerApp({super.key});

  @override
  State<BikeTrackerApp> createState() => _BikeTrackerAppState();
}

class _BikeTrackerAppState extends State<BikeTrackerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resumeAutomaticTracking();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeAutomaticTracking();
    }
  }

  void _resumeAutomaticTracking() {
    AutomaticTrackingService.instance
        .startIfEnabled()
        .then((started) {
          if (!started) {
            debugPrint(
              '[AutomaticTracking] Monitoring was not started '
              '(preference is off or required access is unavailable).',
            );
          }
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('[AutomaticTracking] Startup failed: $error');
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Bike Tracker',

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,

        // ============================================================
        // DARK BROWN THEME
        // ============================================================
        scaffoldBackgroundColor: const Color(0xFF120D0A),

        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFB8754D),
          secondary: Color(0xFFD6A06A),
          surface: Color(0xFF211510),

          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onSurface: Color(0xFFF5EDE7),

          error: Color(0xFFD96C5F),
          onError: Colors.white,
        ),

        // ============================================================
        // CARDS
        // ============================================================
        cardTheme: CardThemeData(
          color: const Color(0xFF211510),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF3B2820), width: 1),
          ),
        ),

        // ============================================================
        // APP BAR
        // ============================================================
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF120D0A),
          foregroundColor: Color(0xFFF5EDE7),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF5EDE7),
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: Color(0xFFD6A06A)),
        ),

        // ============================================================
        // NAVIGATION BAR
        // ============================================================
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1A100C),
          elevation: 0,

          indicatorColor: const Color(0xFFB8754D),

          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: Color(0xFFF5EDE7),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              );
            }

            return const TextStyle(color: Color(0xFF9E8D83), fontSize: 12);
          }),

          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Colors.white);
            }

            return const IconThemeData(color: Color(0xFF9E8D83));
          }),
        ),

        // ============================================================
        // BUTTONS
        // ============================================================
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B5A3C),
            foregroundColor: Colors.white,

            elevation: 3,

            shadowColor: const Color(0xFFB8754D).withValues(alpha: 0.25),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),

            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),

        // ============================================================
        // DIVIDERS
        // ============================================================
        dividerTheme: const DividerThemeData(
          color: Color(0xFF3B2820),
          thickness: 1,
        ),

        // ============================================================
        // DIALOGS
        // ============================================================
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF211510),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF3B2820)),
          ),
          titleTextStyle: const TextStyle(
            color: Color(0xFFF5EDE7),
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
          contentTextStyle: const TextStyle(
            color: Color(0xFFB9AAA2),
            fontSize: 15,
          ),
        ),
      ),

      home: const MainNavigationScreen(),
    );
  }
}

// ============================================================================
// MAIN NAVIGATION
// ============================================================================

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final AutomaticTrackingService _automaticTracking =
      AutomaticTrackingService.instance;
  final GlobalKey<_HomeScreenTabState> _homeKey =
      GlobalKey<_HomeScreenTabState>();
  TrackingProgress _manualProgress = const TrackingProgress();
  bool _hasManualTrackingScreen = false;
  bool _showRideScreen = false;
  bool _showAutomaticRideScreen = false;

  @override
  void initState() {
    super.initState();
    _automaticTracking.addListener(_onAutomaticTrackingChanged);
  }

  void _onAutomaticTrackingChanged() {
    if (!mounted) return;
    setState(() {
      if (_showAutomaticRideScreen && !_automaticTracking.isRideActive) {
        _showAutomaticRideScreen = false;
        _showRideScreen = false;
      }
    });
    if (!_automaticTracking.isRideActive) {
      _homeKey.currentState?._loadTodayStats();
    }
  }

  void _onManualProgressChanged(TrackingProgress progress) {
    if (_manualProgress.isActive == progress.isActive &&
        _manualProgress.distanceKm == progress.distanceKm &&
        _manualProgress.durationSeconds == progress.durationSeconds) {
      return;
    }
    setState(() => _manualProgress = progress);
  }

  void _startManualRideScreen() {
    setState(() {
      _hasManualTrackingScreen = true;
      _showRideScreen = true;
      _showAutomaticRideScreen = false;
    });
  }

  void _viewActiveRide() {
    if (!_manualProgress.isActive && !_automaticTracking.isRideActive) return;

    setState(() {
      _showRideScreen = true;
      if (_manualProgress.isActive && _hasManualTrackingScreen) {
        _showAutomaticRideScreen = false;
      } else {
        _showAutomaticRideScreen = true;
      }
    });
  }

  void _returnHome() {
    setState(() {
      _showRideScreen = false;
      _showAutomaticRideScreen = false;
      if (!_manualProgress.isActive) {
        _hasManualTrackingScreen = false;
        _manualProgress = const TrackingProgress();
      }
    });
  }

  void _onManualRideFinished() {
    setState(() {
      _showRideScreen = false;
      _hasManualTrackingScreen = false;
      _manualProgress = const TrackingProgress();
    });
    _homeKey.currentState?._loadTodayStats();
  }

  @override
  void dispose() {
    _automaticTracking.removeListener(_onAutomaticTrackingChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manualRideActive = _manualProgress.isActive;
    final automaticRideActive = _automaticTracking.isRideActive;
    final rideIsActive = manualRideActive || automaticRideActive;
    final activeDistance = manualRideActive
        ? _manualProgress.distanceKm
        : _automaticTracking.activeDistanceKm;
    final activeDuration = manualRideActive
        ? _manualProgress.durationSeconds
        : _automaticTracking.activeDurationSeconds;
    final showAutomaticView = automaticRideActive || _showAutomaticRideScreen;

    return PopScope<Object?>(
      canPop: !_showRideScreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showRideScreen) _returnHome();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _showRideScreen
              ? (_showAutomaticRideScreen ? 4 : 3)
              : _currentIndex,
          children: [
            HomeScreenTab(
              key: _homeKey,
              isRideInProgress: rideIsActive,
              activeDistanceKm: activeDistance,
              activeDurationSeconds: activeDuration,
              onStartRide: _startManualRideScreen,
              onViewRide: _viewActiveRide,
            ),
            const HistoryScreen(),
            const StatsScreen(),
            _hasManualTrackingScreen
                ? TrackingScreen(
                    onProgressChanged: _onManualProgressChanged,
                    onClose: _returnHome,
                    onRideFinished: _onManualRideFinished,
                  )
                : const SizedBox.shrink(),
            showAutomaticView
                ? TrackingScreen(
                    key: const ValueKey('automatic-ride-view'),
                    automaticRideViewOnly: true,
                    onClose: _returnHome,
                  )
                : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: _showRideScreen
            ? null
            : NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history),
                    label: 'Rides',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart),
                    label: 'Stats',
                  ),
                ],
              ),
      ),
    );
  }
}

// ============================================================================
// HOME SCREEN
// ============================================================================

class HomeScreenTab extends StatefulWidget {
  const HomeScreenTab({
    super.key,
    required this.isRideInProgress,
    required this.activeDistanceKm,
    required this.activeDurationSeconds,
    required this.onStartRide,
    required this.onViewRide,
  });

  final bool isRideInProgress;
  final double activeDistanceKm;
  final int activeDurationSeconds;
  final VoidCallback onStartRide;
  final VoidCallback onViewRide;

  @override
  State<HomeScreenTab> createState() => _HomeScreenTabState();
}

class _HomeScreenTabState extends State<HomeScreenTab> {
  final LocationService _locationService = LocationService();

  StreamSubscription<Position>? _locationSubscription;
  ml.MapLibreMapController? _mapController;
  Position? _currentPosition;
  bool _homeIntroAnimationAttempted = false;
  bool _homeMapUserInteracted = false;
  double _todayDistance = 0.0;
  int _todayDurationSeconds = 0;
  bool _isLoadingToday = true;
  bool _isMetric = true;

  @override
  void initState() {
    super.initState();
    _loadTodayStats();
    _startHomeLocationUpdates();
  }

  Future<void> _startHomeLocationUpdates() async {
    try {
      if (!await _locationService.checkPermission()) return;

      final initialPosition = await _locationService.getCurrentLocation();
      if (!mounted) return;
      if (initialPosition != null) {
        setState(() => _currentPosition = initialPosition);
        _startHomeMapIntroAnimation();
      }

      _locationSubscription = _locationService.getPositionStream().listen(
        (position) {
          if (!mounted) return;
          setState(() => _currentPosition = position);
          _startHomeMapIntroAnimation();
        },
        onError: (Object error) {
          debugPrint('[HomeMap] Location stream failed: $error');
        },
      );
    } catch (error) {
      debugPrint('[HomeMap] Could not start location updates: $error');
    }
  }

  bool _hasValidHomeMapPosition(Position? position) {
    if (position == null ||
        !position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude < -90 ||
        position.latitude > 90 ||
        position.longitude < -180 ||
        position.longitude > 180 ||
        position.accuracy > 100) {
      return false;
    }

    final age = DateTime.now().difference(position.timestamp);
    return age <= const Duration(minutes: 2) &&
        age >= const Duration(seconds: -30);
  }

  Future<void> _startHomeMapIntroAnimation() async {
    if (_homeIntroAnimationAttempted) return;

    final controller = _mapController;
    final position = _currentPosition;
    if (controller == null || !_hasValidHomeMapPosition(position)) return;

    _homeIntroAnimationAttempted = true;
    final target = ml.LatLng(position!.latitude, position.longitude);

    if (_homeMapUserInteracted) return;

    if (AutomaticTrackingService.instance.isRideActive) {
      await controller.animateCamera(
        ml.CameraUpdate.newLatLngZoom(target, 15),
        duration: const Duration(milliseconds: 350),
      );
      return;
    }

    try {
      await controller.animateCamera(
        ml.CameraUpdate.newLatLngZoom(target, 15),
        duration: const Duration(milliseconds: 3200),
      );
    } catch (error) {
      debugPrint('[HomeMap] Intro camera animation failed: $error');
    }
  }

  void _onHomeMapPointerDown(PointerDownEvent event) {
    _homeMapUserInteracted = true;
  }

  Future<void> _recenterHomeMap() async {
    var position = _currentPosition;
    if (position == null) {
      position = await _locationService.getCurrentLocation();
      if (!mounted || position == null) return;
      setState(() => _currentPosition = position);
    }

    await _mapController?.animateCamera(
      ml.CameraUpdate.newLatLngZoom(
        ml.LatLng(position.latitude, position.longitude),
        15,
      ),
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  // ========================================================================
  // LOAD TODAY'S STATS
  // ========================================================================

  Future<void> _loadTodayStats() async {
    try {
      final metric = await SettingsService.instance.isMetric();

      final stats = await DatabaseService.instance.getTodayStats();

      if (!mounted) return;

      setState(() {
        _isMetric = metric;

        _todayDistance = (stats['totalDistance'] as double?) ?? 0.0;

        _todayDurationSeconds = (stats['totalDurationSeconds'] as int?) ?? 0;

        _isLoadingToday = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingToday = false;
        });
      }
    }
  }

  // ========================================================================
  // FORMAT DURATION
  // ========================================================================

  String _formatTodayDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSecs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSecs.toString().padLeft(2, '0')}';
  }

  String _formatActiveRideDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSecs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${remainingSecs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSecs.toString().padLeft(2, '0')}';
  }

  Widget _activeRideCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.two_wheeler,
                  color: Color(0xFFD6A06A),
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Ride in Progress',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF5EDE7),
                    ),
                  ),
                ),
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD6A06A),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _activeRideMetric(
                    SettingsService.formatDistance(
                      widget.activeDistanceKm,
                      _isMetric,
                    ),
                    'Distance',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _activeRideMetric(
                    _formatActiveRideDuration(widget.activeDurationSeconds),
                    'Duration',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: widget.onViewRide,
                icon: const Icon(Icons.open_in_new),
                label: const Text('VIEW RIDE'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD6A06A),
                  side: const BorderSide(color: Color(0xFF8B5A3C)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeRideMetric(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF5EDE7),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFFB9AAA2)),
        ),
      ],
    );
  }

  // ========================================================================
  // ABOUT
  // ========================================================================

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Bike Tracker',
      applicationVersion: '1.0.0',

      applicationIcon: const Icon(
        Icons.two_wheeler,
        size: 48,
        color: Color(0xFFD6A06A),
      ),

      children: const [
        Text(
          'A modern GPS-enabled motorcycle & bicycle tracking '
          'application built with Flutter, SQLite, OpenStreetMap, '
          'and Geolocator.',
        ),
      ],
    );
  }

  // ========================================================================
  // BUILD
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RideForge',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        actions: [
          // SETTINGS
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',

            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );

              _loadTodayStats();
            },
          ),

          // ABOUT
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',

            onPressed: () => _showAboutDialog(context),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            const SizedBox(height: 20),

            // ==============================================================
            // WELCOME HEADER
            // ==============================================================
            const Text(
              'Ready to Ride?',
              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF5EDE7),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Recording starts automatically when speed stays above 20 km/h',
              textAlign: TextAlign.center,

              style: TextStyle(fontSize: 15, color: Color(0xFFB9AAA2)),
            ),

            const SizedBox(height: 35),

            // ==============================================================
            // LIVE MAP CARD
            // ==============================================================
            Listener(
              onPointerDown: _onHomeMapPointerDown,
              child: Card(
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: 220,
                  child: RideMapWidget(
                    routePoints: const [],
                    currentLocation: _currentPosition == null
                        ? null
                        : LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                    currentLocationTimestamp: _currentPosition?.timestamp,
                    currentLocationAccuracyMeters: _currentPosition?.accuracy,
                    showRecenterButton: true,
                    initialCameraTarget: const LatLng(22.5, 79.0),
                    initialZoom: 3.5,
                    styleString: MapStyleConfig.lightStyleUrl,
                    captureGestures: true,
                    onMapReady: (controller) {
                      _mapController = controller;
                      _startHomeMapIntroAnimation();
                    },
                    onRecenter: _recenterHomeMap,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ==============================================================
            // START RIDE BUTTON
            // ==============================================================
            if (widget.isRideInProgress)
              _activeRideCard()
            else
              SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: widget.onStartRide,
                  icon: const Icon(Icons.play_arrow, size: 28),
                  label: const Text(
                    'READY TO RIDE',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 35),

            // ==============================================================
            // TODAY'S ACTIVITY
            // ==============================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [
                const Text(
                  "Today's Activity",

                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF5EDE7),
                  ),
                ),

                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    size: 20,
                    color: Color(0xFFB8754D),
                  ),

                  onPressed: _loadTodayStats,

                  tooltip: 'Refresh',
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                // ==========================================================
                // DISTANCE
                // ==========================================================

                Expanded(
                  child: _statCard(
                    Icons.route,

                    _isLoadingToday
                        ? '...'
                        : SettingsService.formatDistance(
                            _todayDistance,
                            _isMetric,
                          ),

                    'Total Distance',

                    const Color(0xFFD6A06A),
                  ),
                ),

                const SizedBox(width: 12),

                // ==========================================================
                // DURATION
                // ==========================================================
                Expanded(
                  child: _statCard(
                    Icons.timer,

                    _isLoadingToday
                        ? '...'
                        : _formatTodayDuration(_todayDurationSeconds),

                    'Active Duration',

                    const Color(0xFFB8754D),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // STAT CARD
  // ========================================================================

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Card(
      elevation: 0,

      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),

        child: Column(
          children: [
            Icon(icon, size: 28, color: color),

            const SizedBox(height: 10),

            Text(
              value,

              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF5EDE7),
              ),
            ),

            const SizedBox(height: 4),

            Text(
              label,

              textAlign: TextAlign.center,

              style: const TextStyle(fontSize: 12, color: Color(0xFFB9AAA2)),
            ),
          ],
        ),
      ),
    );
  }
}
