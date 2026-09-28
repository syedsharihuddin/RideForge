import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/database_service.dart';
import '../services/automatic_tracking_service.dart';
import '../services/location_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isMetric = true;
  bool _keepScreenOn = true;
  bool _automaticTracking = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final metric = await SettingsService.instance.isMetric();
    final wakelock = await SettingsService.instance.keepScreenOn();
    final automaticTracking =
    await SettingsService.instance.automaticTracking();
    if (!mounted) return;

    setState(() {
  _isMetric = metric;
  _keepScreenOn = wakelock;
  _automaticTracking = automaticTracking;
  _isLoading = false;
});
  }

  Future<void> _toggleMetric(bool value) async {
    await SettingsService.instance.setMetric(value);
    setState(() {
      _isMetric = value;
    });
  }

  Future<void> _toggleKeepScreenOn(bool value) async {
    await SettingsService.instance.setKeepScreenOn(value);
    setState(() {
      _keepScreenOn = value;
    });
  }
 Future<void> _toggleAutomaticTracking(bool value) async {
  if (value) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Automatic Tracking?'),
        content: const Text(
          'RideForge will continuously monitor your location in the '
          'background to automatically detect your rides.\n\n'
          'This feature consumes more battery because location monitoring '
          'continues even when the app is not open.\n\n'
          'Android may ask you to allow location access "All the time".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ENABLE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final locationService = LocationService();

    final hasPermission =
        await locationService.checkBackgroundPermission();

    if (!hasPermission) {
      if (!mounted) return;

      final openSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Background Location Required'),
          content: const Text(
            'To automatically detect rides while RideForge is '
            'closed or minimized, Android needs location access '
            '"All the time".\n\n'
            'Please enable it in Android Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('OPEN SETTINGS'),
            ),
          ],
        ),
      );

      if (openSettings == true) {
        await locationService.openLocationSettings();
      }

      return;
    }

    await SettingsService.instance.setAutomaticTracking(true);

    final started =
        await AutomaticTrackingService.instance.start();

    if (!started) {
      await SettingsService.instance.setAutomaticTracking(false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to start automatic tracking.',
          ),
        ),
      );

      return;
    }

    if (!mounted) return;

    setState(() {
      _automaticTracking = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Automatic Tracking is now active.',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  } else {
    await AutomaticTrackingService.instance.stop();

    await SettingsService.instance.setAutomaticTracking(false);

    if (!mounted) return;

    setState(() {
      _automaticTracking = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Automatic Tracking disabled.',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

  Future<void> _confirmClearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Ride Data?'),
        content: const Text(
          'This will permanently delete all your recorded rides, routes, and statistics. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CLEAR ALL'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService.instance.deleteAllRides();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('All ride history has been cleared.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // -----------------------------------------------------------------
          // UNITS SECTION
          // -----------------------------------------------------------------
          _sectionHeader('MEASUREMENT UNITS'),

          SwitchListTile(
            secondary: const Icon(Icons.straighten, color: Colors.blueAccent),
            title: const Text('Metric Units'),
            subtitle: Text(
              _isMetric
                  ? 'Kilometers (km) & km/h'
                  : 'Miles (mi) & mph',
            ),
            value: _isMetric,
            onChanged: _toggleMetric,
          ),

          const Divider(),

          // -----------------------------------------------------------------
          // DISPLAY & HARDWARE SECTION
          // -----------------------------------------------------------------
          _sectionHeader('DISPLAY & BATTERY'),

          _sectionHeader('DISPLAY & BATTERY'),

SwitchListTile(
  secondary: const Icon(
    Icons.radar,
    color: Colors.orangeAccent,
  ),
  title: const Text('Automatic Trip Detection'),
  subtitle: Text(
    _automaticTracking
        ? 'Automatically detect rides in the background'
        : 'Automatically detect rides while monitoring is enabled',
  ),
  value: _automaticTracking,
  onChanged: _toggleAutomaticTracking,
),

if (_automaticTracking)
  const Padding(
    padding: EdgeInsets.fromLTRB(72, 0, 16, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.battery_alert_outlined,
          size: 18,
          color: Colors.orangeAccent,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Uses more battery because RideForge continuously monitors '
            'your location in the background.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    ),
  ),

SwitchListTile(
  secondary: const Icon(
    Icons.wb_sunny_outlined,
    color: Colors.amberAccent,
  ),
  title: const Text('Keep Screen Awake'),
  subtitle: const Text(
    'Prevents display sleep during active rides',
  ),
  value: _keepScreenOn,
  onChanged: _toggleKeepScreenOn,
),

          ListTile(
  leading: const Icon(
    Icons.location_searching,
    color: Colors.grey,
  ),
  title: const Text('Background Location Tracking'),
  subtitle: const Text(
    'Background monitoring will activate when Automatic Trip Detection is enabled',
  ),
  trailing: Icon(
    _automaticTracking
        ? Icons.pending_outlined
        : Icons.info_outline,
    color: _automaticTracking
        ? Colors.orangeAccent
        : Colors.grey,
    size: 22,
  ),
),

          const Divider(),

          // -----------------------------------------------------------------
          // DATA MANAGEMENT SECTION
          // -----------------------------------------------------------------
          _sectionHeader('DATA MANAGEMENT'),

          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
            title: const Text(
              'Clear All Ride History',
              style: TextStyle(color: Colors.redAccent),
            ),
            subtitle: const Text('Permanently wipe all saved rides and metrics'),
            onTap: _confirmClearAllData,
          ),

          const Divider(),

          // -----------------------------------------------------------------
          // ABOUT SECTION
          // -----------------------------------------------------------------
          _sectionHeader('ABOUT'),

          const ListTile(
            leading: Icon(Icons.two_wheeler, color: Colors.blueAccent),
            title: Text('Bike Tracker'),
            subtitle: Text('Version 1.0.0 • Portfolio Project'),
          ),

          const ListTile(
            leading: Icon(Icons.code, color: Colors.grey),
            title: Text('Architecture'),
            subtitle: Text('Flutter, SQLite, OpenStreetMap, Geolocator'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
