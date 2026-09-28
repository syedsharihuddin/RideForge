import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'ride_events';
  static const String _channelName = 'Ride Events';
  static const String _channelDescription =
      'Notifications when a ride starts or ends';

  static const int _rideStartedId = 1001;
  static const int _rideEndedId = 1002;

  bool _initialized = false;

  /// Called when a notification is tapped.
  void Function(String? payload)? onNotificationTap;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('ic_launcher');

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> showRideStarted() async {
    await _ensureInitialized();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'Ride started',
    );

    await _plugin.show(
      id: _rideStartedId,
      title: '🏍️ Ride Started',
      body: 'RideForge detected that your ride has started.',
      notificationDetails: const NotificationDetails(
        android: androidDetails,
      ),
    );
  }

  Future<void> showRideEnded({
    required int rideId,
    required double distanceKm,
    required int durationSeconds,
    required double maxSpeedKmh,
  }) async {
    await _ensureInitialized();

    final duration = _formatDuration(durationSeconds);

    final distance = distanceKm.toStringAsFixed(1);
    final maxSpeed = maxSpeedKmh.toStringAsFixed(0);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'Ride completed',
    );

    await _plugin.show(
      id: _rideEndedId,
      title: '🏁 Ride Complete',
      body: '$distance km • $duration • Max $maxSpeed km/h',
      payload: rideId.toString(),
      notificationDetails: const NotificationDetails(
        android: androidDetails,
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes}m';
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
}