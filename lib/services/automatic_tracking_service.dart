import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/ride_thresholds.dart';
import '../models/ride.dart';
import 'auto_ride_gate.dart';
import 'database_service.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'settings_service.dart';

class AutomaticTrackingService extends ChangeNotifier {
  static final AutomaticTrackingService instance =
      AutomaticTrackingService._internal();

  AutomaticTrackingService._internal();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _timeoutTimer;
  Timer? _reconnectTimer;
  Future<bool>? _startOperation;

  final AutoRideGate _gate = AutoRideGate();
  final List<Position> _routePoints = [];

  Position? _lastPosition;

  DateTime? _rideStartTime;

  double _distance = 0.0;
  double _maxSpeed = 0.0;
  double _currentSpeedKmh = 0.0;

  bool _running = false;
  bool _connecting = false;
  int _streamGeneration = 0;
  int _reconnectAttempt = 0;
  DateTime? _lastValidGpsSampleAt;

  // Prevents multiple finish operations for the same ride.
  bool _savingRide = false;

  bool get isRunning => _running;
  bool get isRideActive => _gate.isRiding;
  double get activeDistanceKm => _gate.isRiding ? _distance : 0.0;
  double get activeMaxSpeedKmh => _gate.isRiding ? _maxSpeed : 0.0;
  double get activeCurrentSpeedKmh => _gate.isRiding ? _currentSpeedKmh : 0.0;
  int get activeDurationSeconds => _rideStartTime == null
      ? 0
      : DateTime.now().difference(_rideStartTime!).inSeconds;
  double get activeAverageSpeedKmh {
    final durationSeconds = activeDurationSeconds;
    if (durationSeconds <= 0) return 0.0;
    return (_distance / (durationSeconds / 3600)).clamp(0.0, _maxSpeed);
  }

  Position? get activeCurrentPosition => _gate.isRiding ? _lastPosition : null;
  List<LatLng> get activeRoutePoints => _gate.isRiding
      ? List.unmodifiable(
          _routePoints.map(
            (position) => LatLng(position.latitude, position.longitude),
          ),
        )
      : const [];

  Future<bool> start() {
    if (_running) {
      debugPrint('[AutomaticTracking] Service already running.');
      return Future<bool>.value(true);
    }

    final startOperation = _startOperation;
    if (startOperation != null) {
      debugPrint('[AutomaticTracking] Startup already in progress.');
      return startOperation;
    }

    debugPrint('[AutomaticTracking] Service startup requested.');
    final operation = _start();
    _startOperation = operation;
    return operation.whenComplete(() {
      if (identical(_startOperation, operation)) {
        _startOperation = null;
      }
    });
  }

  /// Loads the saved preference and starts monitoring only when enabled.
  Future<bool> startIfEnabled() async {
    final enabled = await SettingsService.instance.automaticTracking();
    debugPrint(
      '[AutomaticTracking] Preference loaded: ${enabled ? 'ON' : 'OFF'}.',
    );
    if (!enabled) {
      if (_running) await stop();
      return false;
    }
    return start();
  }

  Future<bool> _start() async {
    final enabled = await SettingsService.instance.automaticTracking();
    debugPrint(
      '[AutomaticTracking] Preference loaded for startup: '
      '${enabled ? 'ON' : 'OFF'}.',
    );

    if (!enabled) {
      return false;
    }

    final permission = await LocationService().checkBackgroundPermission(
      requestIfDenied: false,
    );

    if (!permission) {
      debugPrint(
        '[AutomaticTracking] Startup skipped: background location '
        'permission or location service unavailable.',
      );
      return false;
    }

    _running = true;

    _resetRideState();
    _reconnectAttempt = 0;
    _connectLocationStream();

    _timeoutTimer?.cancel();

    _timeoutTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkTimeout(),
    );

    debugPrint('[AutomaticTracking] Service started.');
    return true;
  }

  Future<void> stop() async {
    debugPrint('[AutomaticTracking] Service stopped.');
    _running = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final subscription = _positionSubscription;
    _positionSubscription = null;
    _streamGeneration++;
    await subscription?.cancel();

    _timeoutTimer?.cancel();
    _timeoutTimer = null;

    _resetRideState();
  }

  void _connectLocationStream() {
    if (!_running || _positionSubscription != null || _connecting) return;
    _connecting = true;
    final generation = ++_streamGeneration;

    late final LocationSettings settings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '🏍️ RideForge Automatic Tracking',
          notificationText: 'Monitoring for rides in the background',
          enableWakeLock: false,
        ),
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    try {
      final stream = Geolocator.getPositionStream(locationSettings: settings);
      _positionSubscription = stream.listen(
        (position) async {
          if (generation == _streamGeneration) {
            await _handlePosition(position);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('[AutomaticTracking] Location stream error: $error');
          _handleStreamEnd(generation, 'error');
        },
        onDone: () => _handleStreamEnd(generation, 'done'),
        cancelOnError: true,
      );
      debugPrint('[AutomaticTracking] Location stream connected.');
    } catch (error) {
      debugPrint('[AutomaticTracking] Location stream connect failed: $error');
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _handleStreamEnd(int generation, String reason) {
    if (generation != _streamGeneration) return;
    _streamGeneration++;
    _positionSubscription = null;
    debugPrint('[AutomaticTracking] Location stream disconnected ($reason).');
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_running || _reconnectTimer?.isActive == true) return;

    final retryExponent = _reconnectAttempt.clamp(0, 5);
    final delaySeconds = 1 << retryExponent;
    _reconnectAttempt++;
    debugPrint(
      '[AutomaticTracking] Location stream restarted in ${delaySeconds}s.',
    );
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;
      if (_running) _connectLocationStream();
    });
  }

  Future<void> _handlePosition(Position position) async {
    if (!_running) {
      return;
    }

    if (position.accuracy > maxGpsAccuracyMeters) {
      return;
    }

    final now = DateTime.now();
    _reconnectAttempt = 0;
    _lastValidGpsSampleAt = position.timestamp;
    debugPrint(
      '[AutomaticTracking] Last valid GPS sample timestamp: '
      '${_lastValidGpsSampleAt!.toIso8601String()}.',
    );

    double speedKmh = position.speed * 3.6;

    if (position.speed <= 0 || speedKmh < 1.8) {
      speedKmh = 0.0;
    }

    final signal = _gate.ingest(
      now: now,
      speedKmh: speedKmh,
      accuracyMeters: position.accuracy,
    );

    // ============================================================
    // RIDE STARTED
    // ============================================================

    if (signal == AutoRideSignal.tripStarted) {
      _beginRide(position, now);

      // Notification failure must never break tracking.
      try {
        await NotificationService.instance.showRideStarted();
      } catch (_) {
        // Ignore notification errors.
      }
    }

    if (_gate.isRiding) {
      _currentSpeedKmh = speedKmh;
      _recordRidePosition(position, speedKmh);
      notifyListeners();
    }
  }

  void _beginRide(Position firstPosition, DateTime now) {
    _rideStartTime = now;

    _distance = 0.0;
    _maxSpeed = 0.0;

    _routePoints.clear();
    _routePoints.add(firstPosition);

    _lastPosition = firstPosition;
  }

  void _recordRidePosition(Position position, double speedKmh) {
    if (_lastPosition != null) {
      final distanceInMeters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      final isMoving = speedKmh >= 1.8 && distanceInMeters >= 5.0;

      final isGoodDisplacement =
          distanceInMeters >= 12.0 && position.accuracy <= 15.0;

      if (isMoving || isGoodDisplacement) {
        _distance += distanceInMeters / 1000.0;

        _routePoints.add(position);

        _lastPosition = position;
      } else if (position.accuracy <= 10.0) {
        _lastPosition = position;
      }
    } else {
      _lastPosition = position;
      _routePoints.add(position);
    }

    if (speedKmh > _maxSpeed) {
      _maxSpeed = speedKmh;
    }
  }

  void _checkTimeout() {
    if (!_running || !_gate.isRiding || _savingRide) {
      return;
    }

    final signal = _gate.checkTimeout(DateTime.now());

    if (signal == AutoRideSignal.tripEnded) {
      _finishRide();
    } else {
      notifyListeners();
    }
  }

  Future<void> _finishRide() async {
    // ============================================================
    // HARD GUARD
    // ============================================================

    if (_savingRide || !_running || _rideStartTime == null) {
      return;
    }

    // Lock immediately.
    _savingRide = true;

    // ============================================================
    // SNAPSHOT THE RIDE
    // ============================================================

    final rideStartTime = _rideStartTime!;
    final rideEndTime = DateTime.now();

    final rideDistance = _distance;
    final rideMaxSpeed = _maxSpeed;

    final rideRoutePoints = List<Position>.from(_routePoints);

    final duration = rideEndTime.difference(rideStartTime);

    final durationHours = duration.inSeconds / 3600.0;

    final averageSpeed = durationHours > 0 ? rideDistance / durationHours : 0.0;

    // ============================================================
    // CRITICAL:
    // RESET THE DETECTOR BEFORE ASYNC DATABASE/NOTIFICATION WORK
    //
    // This prevents the 1-second timeout timer from seeing the
    // same ride as "ended" again.
    // ============================================================

    _resetRideState();

    try {
      final ride = Ride(
        startTime: rideStartTime,
        endTime: rideEndTime,
        distance: rideDistance,
        durationSeconds: duration.inSeconds,
        averageSpeed: averageSpeed,
        maxSpeed: rideMaxSpeed,
        routePoints: rideRoutePoints
            .map((position) => LatLng(position.latitude, position.longitude))
            .toList(),
      );

      // ============================================================
      // SAVE EXACTLY ONCE
      // ============================================================

      final rideId = await DatabaseService.instance.insertRide(ride);

      // ============================================================
      // COMPLETION NOTIFICATION
      //
      // Notification failure must NOT affect the saved ride.
      // ============================================================

      try {
        await NotificationService.instance.showRideEnded(
          rideId: rideId,
          distanceKm: rideDistance,
          durationSeconds: duration.inSeconds,
          maxSpeedKmh: rideMaxSpeed,
        );
      } catch (_) {
        // Ignore notification errors.
      }
    } catch (_) {
      // Keep automatic tracking alive even if saving fails.
    } finally {
      _savingRide = false;
    }
  }

  void _resetRideState() {
    _gate.phase = RidePhase.detecting;

    _lastPosition = null;
    _rideStartTime = null;

    _routePoints.clear();

    _distance = 0.0;
    _maxSpeed = 0.0;
    _currentSpeedKmh = 0.0;
    notifyListeners();
  }
}
