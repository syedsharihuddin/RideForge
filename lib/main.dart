import 'package:flutter/material.dart';
import 'screens/tracking_screen.dart';
import 'screens/history_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';
import 'services/database_service.dart';
import 'services/settings_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BikeTrackerApp());
}

class BikeTrackerApp extends StatelessWidget {
  const BikeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
            side: const BorderSide(
              color: Color(0xFF3B2820),
              width: 1,
            ),
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
          iconTheme: IconThemeData(
            color: Color(0xFFD6A06A),
          ),
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

            return const TextStyle(
              color: Color(0xFF9E8D83),
              fontSize: 12,
            );
          }),

          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                color: Colors.white,
              );
            }

            return const IconThemeData(
              color: Color(0xFF9E8D83),
            );
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
            side: const BorderSide(
              color: Color(0xFF3B2820),
            ),
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
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreenTab(),
          HistoryScreen(),
          StatsScreen(),
        ],
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,

        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
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
    );
  }
}

// ============================================================================
// HOME SCREEN
// ============================================================================

class HomeScreenTab extends StatefulWidget {
  const HomeScreenTab({super.key});

  @override
  State<HomeScreenTab> createState() => _HomeScreenTabState();
}

class _HomeScreenTabState extends State<HomeScreenTab> {
  double _todayDistance = 0.0;
  int _todayDurationSeconds = 0;
  bool _isLoadingToday = true;
  bool _isMetric = true;

  @override
  void initState() {
    super.initState();
    _loadTodayStats();
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
        _todayDistance =
            (stats['totalDistance'] as double?) ?? 0.0;
        _todayDurationSeconds =
            (stats['totalDurationSeconds'] as int?) ?? 0;
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
          'Bike Tracker',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          // SETTINGS
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',

            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
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

              style: TextStyle(
                fontSize: 15,
                color: Color(0xFFB9AAA2),
              ),
            ),

            const SizedBox(height: 35),

            // ==============================================================
            // GPS READY CARD
            // ==============================================================

            Card(
              elevation: 0,

              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 30,
                ),

                child: Column(
                  children: [
                    // MOTORCYCLE ICON
                    Container(
                      padding: const EdgeInsets.all(18),

                      decoration: BoxDecoration(
                        color: const Color(0xFFB8754D)
                            .withValues(alpha: 0.15),

                        shape: BoxShape.circle,

                        border: Border.all(
                          color: const Color(0xFFB8754D)
                              .withValues(alpha: 0.35),
                        ),
                      ),

                      child: const Icon(
                        Icons.two_wheeler,
                        size: 48,
                        color: Color(0xFFD6A06A),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'GPS Tracking Ready',

                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF5EDE7),
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Tap below, then ride — the trip starts after sustained speed above 20 km/h',

                      textAlign: TextAlign.center,

                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFB9AAA2),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ==============================================================
            // START RIDE BUTTON
            // ==============================================================

            SizedBox(
              height: 58,

              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,

                    MaterialPageRoute(
                      builder: (context) =>
                          const TrackingScreen(),
                    ),
                  );

                  // Refresh today's statistics
                  _loadTodayStats();
                },

                icon: const Icon(
                  Icons.play_arrow,
                  size: 28,
                ),

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
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,

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
                        : _formatTodayDuration(
                            _todayDurationSeconds,
                          ),

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

  Widget _statCard(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Card(
      elevation: 0,

      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 16,
        ),

        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: color,
            ),

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

              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFB9AAA2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}