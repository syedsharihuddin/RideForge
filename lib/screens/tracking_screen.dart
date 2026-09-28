import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'trip_summary_screen.dart';
import '../config/ride_thresholds.dart';
import '../services/auto_ride_gate.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../widgets/ride_map_widget.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final LocationService _locationService = LocationService();
  final AutoRideGate _rideGate = AutoRideGate();

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

  bool get _isRiding => _rideGate.isRiding;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
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
    }

    final isMetric = await SettingsService.instance.isMetric();
    final keepScreenOn = await SettingsService.instance.keepScreenOn();

    if (!mounted) return;

    setState(() {
      _isMetric = isMetric;
      _keepScreenOn = keepScreenOn;
      _isLoading = false;
    });

    _startHeartbeat();
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

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF6F513D),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Ride started — speed above ${tripStartSpeedKmh.toStringAsFixed(0)} km/h.',
        ),
      ),
    );
  }

  void _startHeartbeat() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isPaused) return;

      if (_isRiding) {
        _elapsedSeconds++;
        _calculateAverageSpeed();

        final signal = _rideGate.checkTimeout(DateTime.now());
        if (signal == AutoRideSignal.tripEnded) {
          _stopRide();
          return;
        }
      }

      setState(() {});
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

    final signal = _rideGate.ingest(
      now: DateTime.now(),
      speedKmh: speedKmh,
      accuracyMeters: position.accuracy,
    );

    if (signal == AutoRideSignal.tripStarted) {
      _lastPosition = position;
      _beginRecording();
      setState(() {});
      return;
    }

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
  }

  void _stopRide() {
    if (_isStopping || !_isRiding) return;
    _isStopping = true;

    _timer?.cancel();
    _positionSubscription?.cancel();
    WakelockPlus.disable();

    final endTime = DateTime.now();
    final duration = Duration(seconds: _elapsedSeconds);

    final points = _routePoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TripSummaryScreen(
          distance: _distance,
          duration: duration,
          averageSpeed: _averageSpeed,
          maxSpeed: _maxSpeed,
          startTime: _startTime ?? DateTime.now(),
          endTime: endTime,
          routePoints: points,
        ),
      ),
    );
  }

  String _formatDuration() {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _formatGrace(Duration remaining) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startProgress = _rideGate.startHoldProgress(now);
    final graceRemaining = _rideGate.stopGraceRemaining(now);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isRiding ? 'Current Ride' : 'Waiting to Ride',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            if (!_isRiding) _buildDetectingBanner(startProgress),
            if (_isRiding && graceRemaining != null)
              _buildStopGraceBanner(graceRemaining),
            SizedBox(
              height: 280,
              child: RideMapWidget(
                routePoints: _mapRoutePoints,
                currentLocation: _lastPosition == null
                    ? null
                    : LatLng(_lastPosition!.latitude, _lastPosition!.longitude),
                currentLocationTimestamp: _lastPosition?.timestamp,
                currentLocationAccuracyMeters: _lastPosition?.accuracy,
                followLocation: _autoFollow,
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
                              ? _currentSpeed
                              : SettingsService.kmhToMph(_currentSpeed))
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
                    SettingsService.formatDistance(_distance, _isMetric),
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
                    SettingsService.formatSpeed(_averageSpeed, _isMetric),
                    'Average',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    Icons.flash_on,
                    SettingsService.formatSpeed(_maxSpeed, _isMetric),
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
            if (_isRiding) ...[
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
                  onPressed: () => Navigator.pop(context),
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

  Widget _buildDetectingBanner(double progress) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'RIDING starts automatically',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Speed must stay above ${tripStartSpeedKmh.toStringAsFixed(0)} km/h '
                'for ${tripStartHoldDuration.inSeconds}s with accurate GPS. '
                'A single spike will not start the trip.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStopGraceBanner(Duration remaining) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Stationary — trip ends in ${_formatGrace(remaining)} '
            'if you stay below ${tripStopSpeedKmh.toStringAsFixed(0)} km/h. '
            'Traffic under ${tripStartSpeedKmh.toStringAsFixed(0)} km/h will not end the ride.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
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
