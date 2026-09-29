import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'trip_summary_screen.dart';
import '../config/ride_thresholds.dart';
import '../services/automatic_tracking_service.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../widgets/ride_map_widget.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({
    super.key,
    this.automaticRideViewOnly = false,
    this.onProgressChanged,
    this.onClose,
    this.onRideFinished,
  });

  final bool automaticRideViewOnly;
  final ValueChanged<TrackingProgress>? onProgressChanged;
  final VoidCallback? onClose;
  final VoidCallback? onRideFinished;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

@immutable
class TrackingProgress {
  const TrackingProgress({
    this.isActive = false,
    this.distanceKm = 0.0,
    this.durationSeconds = 0,
  });

  final bool isActive;
  final double distanceKm;
  final int durationSeconds;
}

class _TrackingScreenState extends State<TrackingScreen> {
  final LocationService _locationService = LocationService();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _timer;

  Position? _lastPosition;
  final List<Position> _routePoints = [];
  List<LatLng> _mapRoutePoints = const [];

  double _currentSpeed = 0.0;
  double _distance = 0.0;
  double _averageSpeed = 0.0;
  double _maxSpeed = 0.0;

  int _elapsedSeconds = 0;

  DateTime? _startTime;
  bool _isPaused = false;
  bool _isLoading = true;
  bool _isMetric = true;
  bool _autoFollow = true;
  bool _keepScreenOn = true;
  bool _isStopping = false;
  bool _manualRideActive = false;

  AutomaticTrackingService get _automaticTracking =>
      AutomaticTrackingService.instance;

  bool get _isRiding => widget.automaticRideViewOnly
      ? _automaticTracking.isRideActive
      : _manualRideActive;
  double get _displayDistance => widget.automaticRideViewOnly
      ? _automaticTracking.activeDistanceKm
      : _distance;
  int get _displayElapsedSeconds => widget.automaticRideViewOnly
      ? _automaticTracking.activeDurationSeconds
      : _elapsedSeconds;
  double get _displayCurrentSpeed => widget.automaticRideViewOnly
      ? _automaticTracking.activeCurrentSpeedKmh
      : _currentSpeed;
  double get _displayAverageSpeed => widget.automaticRideViewOnly
      ? _automaticTracking.activeAverageSpeedKmh
      : _averageSpeed;
  double get _displayMaxSpeed => widget.automaticRideViewOnly
      ? _automaticTracking.activeMaxSpeedKmh
      : _maxSpeed;

  @override
  void initState() {
    super.initState();
    if (widget.automaticRideViewOnly) {
      _isLoading = false;
      _loadMetricPreference();
    } else {
      _beginRecording();
      _manualRideActive = true;
      _isLoading = false;
      _startHeartbeat();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _notifyRideProgress();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF6F513D),
            behavior: SnackBarBehavior.floating,
            content: Text('Ride started.'),
          ),
        );
      });
      _startMonitoring();
    }
  }

  Future<void> _loadMetricPreference() async {
    final isMetric = await SettingsService.instance.isMetric();
    if (!mounted) return;
    setState(() => _isMetric = isMetric);
  }

  Future<void> _startMonitoring() async {
    final hasPermission = await _locationService.checkPermission();

    if (!hasPermission) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required to track your ride.'),
        ),
      );

      return;
    }

    final initialPosition = await _locationService.getCurrentLocation();

    if (!mounted) return;

    if (initialPosition != null) {
      _lastPosition = initialPosition;
      if (_routePoints.isEmpty) {
        _routePoints.add(initialPosition);
        _mapRoutePoints = [
          LatLng(initialPosition.latitude, initialPosition.longitude),
        ];
      }
    }

    final isMetric = await SettingsService.instance.isMetric();
    final keepScreenOn = await SettingsService.instance.keepScreenOn();

    if (!mounted) return;

    setState(() {
      _isMetric = isMetric;
      _keepScreenOn = keepScreenOn;
      _isLoading = false;
    });

    if (keepScreenOn) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
    _startLocationStream();
  }

  void _beginRecording() {
    _startTime = DateTime.now();
    _elapsedSeconds = 0;
    _distance = 0.0;
    _averageSpeed = 0.0;
    _maxSpeed = 0.0;
    _routePoints.clear();
    if (_lastPosition != null) {
      _routePoints.add(_lastPosition!);
      _mapRoutePoints = [
        LatLng(_lastPosition!.latitude, _lastPosition!.longitude),
      ];
    } else {
      _mapRoutePoints = const [];
    }

    if (_keepScreenOn) {
      WakelockPlus.enable();
    }
  }

  void _startHeartbeat() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isPaused) return;

      if (_isRiding) {
        _elapsedSeconds++;
        _calculateAverageSpeed();
      }

      setState(() {});
      _notifyRideProgress();
    });
  }

  void _startLocationStream() {
    _positionSubscription?.cancel();

    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: "🏍️ Bike Tracker Active",
          notificationText: "Tracking your ride in the background",
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
              if (_isPaused || !mounted || _isStopping) return;
              _updateRideData(position);
            });
  }

  void _updateRideData(Position position) {
    final speedKmh = position.speed < 0 ? 0.0 : position.speed * 3.6;
    _currentSpeed = speedKmh < 1.8 ? 0.0 : speedKmh;

    if (!_isRiding) {
      _lastPosition = position;
      setState(() {});
      return;
    }

    if (position.accuracy > maxGpsAccuracyMeters) {
      setState(() {});
      return;
    }

    double filteredSpeed = speedKmh;
    if (filteredSpeed < 1.8 || position.speed <= 0) {
      filteredSpeed = 0.0;
    }

    if (_lastPosition != null) {
      final distanceInMeters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      final isMoving = filteredSpeed >= 1.8 && distanceInMeters >= 5.0;
      final isDisplacement =
          distanceInMeters >= 12.0 && position.accuracy <= 15.0;

      if (isMoving || isDisplacement) {
        _distance += distanceInMeters / 1000.0;
        _routePoints.add(position);
        _mapRoutePoints = [
          ..._mapRoutePoints,
          LatLng(position.latitude, position.longitude),
        ];
        _lastPosition = position;
      } else if (position.accuracy <= 10.0 && distanceInMeters < 5.0) {
        _lastPosition = position;
      }
    } else {
      _lastPosition = position;
      _routePoints.add(position);
      _mapRoutePoints = [LatLng(position.latitude, position.longitude)];
    }

    if (filteredSpeed > _maxSpeed) {
      _maxSpeed = filteredSpeed;
    }

    _currentSpeed = filteredSpeed;
    _calculateAverageSpeed();

    setState(() {});
    _notifyRideProgress();
  }

  void _notifyRideProgress({bool? activeOverride}) {
    widget.onProgressChanged?.call(
      TrackingProgress(
        isActive: activeOverride ?? (_isRiding && !_isStopping),
        distanceKm: _distance,
        durationSeconds: _elapsedSeconds,
      ),
    );
  }

  void _calculateAverageSpeed() {
    if (_elapsedSeconds < 3 || _distance < 0.02) {
      _averageSpeed = 0.0;
      return;
    }

    final hours = _elapsedSeconds / 3600.0;
    final calculatedAvg = _distance / hours;

    _averageSpeed = calculatedAvg > _maxSpeed ? _maxSpeed : calculatedAvg;
  }

  void _togglePause() {
    if (!_isRiding) return;
    setState(() {
      _isPaused = !_isPaused;
    });
    _notifyRideProgress();
  }

  void _stopRide() {
    if (_isStopping || !_isRiding) return;
    _isStopping = true;
    _manualRideActive = false;
    _notifyRideProgress(activeOverride: false);

    _timer?.cancel();
    _positionSubscription?.cancel();
    WakelockPlus.disable();

    final endTime = DateTime.now();
    final duration = Duration(seconds: _elapsedSeconds);

    final points = _routePoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    if (!mounted) return;

    final summaryRoute = MaterialPageRoute<void>(
      builder: (context) => TripSummaryScreen(
        distance: _distance,
        duration: duration,
        averageSpeed: _averageSpeed,
        maxSpeed: _maxSpeed,
        startTime: _startTime ?? DateTime.now(),
        endTime: endTime,
        routePoints: points,
      ),
    );

    if (widget.onRideFinished == null) {
      Navigator.pushReplacement(context, summaryRoute);
    } else {
      Navigator.push(context, summaryRoute).then((_) {
        widget.onRideFinished?.call();
      });
    }
  }

  String _formatDuration() {
    final hours = _displayElapsedSeconds ~/ 3600;
    final minutes = (_displayElapsedSeconds % 3600) ~/ 60;
    final seconds = _displayElapsedSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    if (!widget.automaticRideViewOnly) {
      WakelockPlus.disable();
    }
    super.dispose();
  }

  void _closeScreen() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPosition = widget.automaticRideViewOnly
        ? _automaticTracking.activeCurrentPosition
        : _lastPosition;
    final routePoints = widget.automaticRideViewOnly
        ? _automaticTracking.activeRoutePoints
        : _mapRoutePoints;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Current Ride',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            SizedBox(
              height: 280,
              child: RideMapWidget(
                routePoints: routePoints,
                currentLocation: currentPosition == null
                    ? null
                    : LatLng(
                        currentPosition.latitude,
                        currentPosition.longitude,
                      ),
                currentLocationTimestamp: currentPosition?.timestamp,
                currentLocationAccuracyMeters: currentPosition?.accuracy,
                followLocation: widget.automaticRideViewOnly || _autoFollow,
                initialZoom: 15,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  children: [
                    const Icon(Icons.speed, size: 45),
                    const SizedBox(height: 10),
                    Text(
                      (_isMetric
                              ? _displayCurrentSpeed
                              : SettingsService.kmhToMph(_displayCurrentSpeed))
                          .toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      SettingsService.speedUnit(_isMetric),
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    Icons.route,
                    SettingsService.formatDistance(_displayDistance, _isMetric),
                    'Distance',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(Icons.timer, _formatDuration(), 'Duration'),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    Icons.speed,
                    SettingsService.formatSpeed(
                      _displayAverageSpeed,
                      _isMetric,
                    ),
                    'Average',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    Icons.flash_on,
                    SettingsService.formatSpeed(_displayMaxSpeed, _isMetric),
                    'Max Speed',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: CircularProgressIndicator(),
              ),
            if (_isRiding && widget.automaticRideViewOnly) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.radio_button_checked,
                        color: Color(0xFFD6A06A),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Automatic ride recording is active.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: _closeScreen,
                        child: const Text('HOME'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_isRiding) ...[
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _togglePause,
                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(
                    _isPaused ? 'RESUME RIDE' : 'PAUSE RIDE',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: _stopRide,
                  icon: const Icon(Icons.stop),
                  label: const Text(
                    'STOP RIDE',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: _closeScreen,
                  icon: const Icon(Icons.close),
                  label: const Text(
                    'CANCEL MONITORING',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, size: 30),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
