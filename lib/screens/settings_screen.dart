import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isMetric = true;
  bool _keepScreenOn = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final metric = await SettingsService.instance.isMetric();
    final wakelock = await SettingsService.instance.keepScreenOn();
    if (!mounted) return;

    setState(() {
      _isMetric = metric;
      _keepScreenOn = wakelock;
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

          SwitchListTile(
            secondary: const Icon(Icons.wb_sunny_outlined, color: Colors.amberAccent),
            title: const Text('Keep Screen Awake'),
            subtitle: const Text('Prevents display sleep during active rides'),
            value: _keepScreenOn,
            onChanged: _toggleKeepScreenOn,
          ),

          ListTile(
            leading: const Icon(Icons.notifications_active_outlined, color: Colors.tealAccent),
            title: const Text('Background Location Tracking'),
            subtitle: const Text(
              'Enabled via persistent notification so tracking continues when screen is locked',
            ),
            trailing: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
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
