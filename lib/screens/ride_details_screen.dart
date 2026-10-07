import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/ride.dart';
import '../theme/ride_forge_visuals.dart';
import '../widgets/ride_map_widget.dart';

class RideDetailsScreen extends StatelessWidget {
  final Ride ride;

  const RideDetailsScreen({super.key, required this.ride});

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    }

    return '${remainingSeconds}s';
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('EEE, d MMM yyyy • h:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final validRoutePoints = ride.routePoints
        .where(_isValidCoordinate)
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Ride Summary'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.motorcycle, size: 48),

              const SizedBox(height: 12),

              const Text(
                'Ride Complete',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 6),

              Text(
                _formatDateTime(ride.startTime),
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.route,
                      label: 'Distance',
                      value: '${ride.distance.toStringAsFixed(1)} km',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.timer,
                      label: 'Duration',
                      value: _formatDuration(ride.durationSeconds),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.speed,
                      label: 'Avg Speed',
                      value: '${ride.averageSpeed.toStringAsFixed(1)} km/h',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.flash_on,
                      label: 'Top Speed',
                      value: '${ride.maxSpeed.toStringAsFixed(0)} km/h',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Text(
                'Route',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (validRoutePoints.isEmpty)
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: RideForgeVisuals.cardDecoration(),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 34,
                        color: Color(0xFFD6A06A),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Route map unavailable',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'GPS route data was not recorded for this ride.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFB9AAA2),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _RoutePreview(points: validRoutePoints),

              const SizedBox(height: 24),

              const Text(
                'Ride Information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              _InfoRow(
                icon: Icons.play_arrow,
                title: 'Started',
                value: _formatDateTime(ride.startTime),
              ),

              _InfoRow(
                icon: Icons.stop,
                title: 'Ended',
                value: _formatDateTime(ride.endTime),
              ),

              _InfoRow(
                icon: Icons.location_on,
                title: 'Route Points',
                value: '${ride.routePoints.length}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isValidCoordinate(LatLng point) =>
    point.latitude.isFinite &&
    point.longitude.isFinite &&
    point.latitude >= -90 &&
    point.latitude <= 90 &&
    point.longitude >= -180 &&
    point.longitude <= 180;

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(value, textAlign: TextAlign.end),
        ],
      ),
    );
  }
}

class _RoutePreview extends StatelessWidget {
  final List<LatLng> points;

  const _RoutePreview({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      width: double.infinity,
      decoration: RideForgeVisuals.cardDecoration(
        color: Colors.transparent,
        highlighted: true,
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: RideMapWidget(
          routePoints: points,
          fitRoute: true,
          showRouteEndpoints: true,
          showRouteControls: true,
          captureGestures: true,
        ),
      ),
    );
  }
}
