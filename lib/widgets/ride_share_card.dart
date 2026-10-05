import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ride.dart';

/// A fixed-size, renderable RideForge share image. It consumes a saved ride
/// and a MapLibre snapshot; it never reads live location or ride storage.
class RideShareCard extends StatelessWidget {
  const RideShareCard({super.key, required this.ride, required this.mapPng});

  final Ride ride;
  final Uint8List mapPng;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, d MMM yyyy').format(ride.startTime);
    final times =
        '${DateFormat('h:mm a').format(ride.startTime)} – '
        '${DateFormat('h:mm a').format(ride.endTime)}';

    return SizedBox(
      width: 432,
      height: 540,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF17110E), Color(0xFF302018)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.motorcycle,
                    color: Color(0xFFD6A06A),
                    size: 28,
                  ),
                  const SizedBox(width: 9),
                  const Text(
                    'RIDEFORGE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'RIDE COMPLETE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                date,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                times,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(mapPng, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _ShareMetric(
                      label: 'DISTANCE',
                      value: '${ride.distance.toStringAsFixed(2)} km',
                      prominent: true,
                    ),
                  ),
                  Expanded(
                    child: _ShareMetric(
                      label: 'DURATION',
                      value: ride.formattedDuration,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: _ShareMetric(
                      label: 'AVG SPEED',
                      value: '${ride.averageSpeed.toStringAsFixed(1)} km/h',
                    ),
                  ),
                  Expanded(
                    child: _ShareMetric(
                      label: 'TOP SPEED',
                      value: '${ride.maxSpeed.toStringAsFixed(1)} km/h',
                    ),
                  ),
                  Expanded(
                    child: _ShareMetric(
                      label: 'GPS POINTS',
                      value: '${ride.routePoints.length}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '© OpenFreeMap · © OpenMapTiles · © OpenStreetMap contributors',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareMetric extends StatelessWidget {
  const _ShareMetric({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.56),
          fontWeight: FontWeight.w700,
          fontSize: 9,
          letterSpacing: 0.75,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: prominent ? const Color(0xFFFFD166) : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: prominent ? 20 : 14,
        ),
      ),
    ],
  );
}
