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
        title: const Text('Enable Background Ride Tracking?'),
        content: const Text(
          'Automatically detects and records rides while RideForge is '
          'running in the background. You can lock your phone and use other '
          'apps while tracking continues.\n\n'
          'Keep RideForge running in the background for reliable automatic '
          'tracking. Do not force-close the app.\n\n'
          'This feature uses more battery. '
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
            'To detect rides while RideForge is running in the background, '
            'Android needs location access "All the time". You can lock your '
            'phone or use other apps, but do not force-close RideForge.\n\n'
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
            'Unable to start Background Ride Tracking.',
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
          'Background Ride Tracking is now active.',
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
          'Background Ride Tracking disabled.',
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
  title: const Text('Background Ride Tracking'),
  subtitle: const Text(
    'Automatically detects and records rides while RideForge is running in the background.',
  ),
  value: _automaticTracking,
  onChanged: _toggleAutomaticTracking,
),

const Padding(
  padding: EdgeInsets.fromLTRB(72, 0, 16, 12),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.info_outline, size: 18, color: Colors.orangeAccent),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          'Keep RideForge running in the background for reliable automatic tracking. Do not force-close the app.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    ],
  ),
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
    'Background monitoring will activate when Background Ride Tracking is enabled',
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
