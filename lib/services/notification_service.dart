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
  static const int _rideEndedIdBase = 2000;

  bool _initialized = false;
  Future<void>? _initialization;

  /// Called when a notification is tapped.
  void Function(String? payload)? onNotificationTap;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    final initialization = _initialization;
    if (initialization != null) return initialization;

    final operation = _initialize();
    _initialization = operation.catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      _initialization = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
    return _initialization!;
  }

  Future<void> _initialize() async {
    const androidSettings = AndroidInitializationSettings('ic_stat_rideforge');

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
          AndroidFlutterLocalNotificationsPlugin
        >();

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

    // Request permission once the plugin and channel are ready. On Android 12
    // and below this is a no-op; Android 13+ shows the runtime permission UI.
    await androidPlugin?.requestNotificationsPermission();

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null) {
      onNotificationTap?.call(launchPayload);
    }

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
      notificationDetails: const NotificationDetails(android: androidDetails),
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
      // Keep completion notifications for separate saved rides visible.
      // Repeated calls for the same ride update the same notification.
      id: _rideEndedNotificationId(rideId),
      title: '🏁 Ride Complete',
      body: '$distance km • $duration • Max $maxSpeed km/h',
      payload: rideId.toString(),
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  String _formatDuration(int seconds) {
    return '${seconds ~/ 60}m';
  }

  int _rideEndedNotificationId(int rideId) =>
      _rideEndedIdBase + (rideId & 0x3fffffff);

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      await initialize();
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }
}
