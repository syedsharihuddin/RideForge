import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ride.dart';

/// A fixed-size portrait RideForge share image backed by saved ride data and a
/// MapLibre snapshot. It never reads live location or ride storage.
class RideShareCard extends StatelessWidget {
  const RideShareCard({super.key, required this.ride, required this.mapPng});

  static const Size shareCardSize = Size(432, 540);

  final Ride ride;
  final Uint8List mapPng;

  static const _warmWhite = Color(0xFFF4EDE5);
  static const _muted = Color(0xFFB7A69A);
  static const _orange = Color(0xFFE89A4A);

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, d MMM yyyy').format(ride.startTime);
    final times =
        '${DateFormat('h:mm a').format(ride.startTime)} – '
        '${DateFormat('h:mm a').format(ride.endTime)}';

    return DefaultTextStyle(
      style: const TextStyle(decoration: TextDecoration.none),
      child: SizedBox.fromSize(
        size: shareCardSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF765033), width: 1.2),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF17120F), Color(0xFF241912), Color(0xFF120E0C)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CustomPaint(painter: _CardAtmospherePainter()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 7),
                      Text(
                        date,
                        style: const TextStyle(
                          color: _warmWhite,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: _orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            times,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8E7E1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0x99D99A56),
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.memory(
                            mapPng,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'RIDE STATISTICS',
                          style: TextStyle(
                            color: Color(0xFFAA988A),
                            fontWeight: FontWeight.w700,
                            fontSize: 8,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 41,
                        child: Row(
                          children: [
                            Expanded(
                              child: _ShareMetric(
                                icon: Icons.route_rounded,
                                label: 'DISTANCE',
                                value: '${ride.distance.toStringAsFixed(2)} km',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ShareMetric(
                                icon: Icons.timer_outlined,
                                label: 'DURATION',
                                value: ride.formattedDuration,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      SizedBox(
                        height: 41,
                        child: Row(
                          children: [
                            Expanded(
                              child: _ShareMetric(
                                icon: Icons.speed_rounded,
                                label: 'AVG SPEED',
                                value:
                                    '${ride.averageSpeed.toStringAsFixed(1)} km/h',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ShareMetric(
                                icon: Icons.trending_up_rounded,
                                label: 'TOP SPEED',
                                value:
                                    '${ride.maxSpeed.toStringAsFixed(1)} km/h',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      SizedBox(
                        height: 32,
                        child: _ShareMetric(
                          icon: Icons.my_location_rounded,
                          label: 'GPS POINTS',
                          value: '${ride.routePoints.length}',
                          compact: true,
                        ),
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 34,
                        child: CustomPaint(
                          painter: _AdventureFooterPainter(),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned(
                                left: 3,
                                bottom: 0,
                                child: Icon(
                                  Icons.motorcycle_rounded,
                                  size: 25,
                                  color: _orange.withValues(alpha: 0.9),
                                ),
                              ),
                              const Positioned(
                                left: 34,
                                right: 0,
                                top: 0,
                                height: 16,
                                child: Center(
                                  child: Text(
                                    'Track every ride. Relive every route.',
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: Color(0xFFE9DDD2),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '© OpenFreeMap  ·  © OpenMapTiles  ·  © OpenStreetMap contributors',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF88776A),
                          fontSize: 7,
                          letterSpacing: 0.05,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Row(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          'Assets/RideForge.png',
          width: 35,
          height: 35,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
      const SizedBox(width: 8),
      const Text(
        'RIDEFORGE',
        style: TextStyle(
          color: _warmWhite,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 1.8,
        ),
      ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x665E493B)),
          color: const Color(0x332B2019),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _orange,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'RIDE COMPLETE',
              style: TextStyle(
                color: Color(0xFFE0D1C5),
                fontWeight: FontWeight.w700,
                fontSize: 9,
                letterSpacing: 0.75,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ShareMetric extends StatelessWidget {
  const _ShareMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: compact ? 17 : 18, color: const Color(0xFFE89A4A)),
      const SizedBox(width: 7),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFFAA988A),
                fontWeight: FontWeight.w700,
                fontSize: 7,
                height: 1,
                letterSpacing: 0.9,
              ),
            ),
            SizedBox(height: compact ? 1 : 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFFFC27A),
                fontWeight: FontWeight.w800,
                fontSize: compact ? 17 : 19,
                height: 1,
                letterSpacing: 0.05,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CardAtmospherePainter extends CustomPainter {
  const _CardAtmospherePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader =
          const RadialGradient(colors: [Color(0x1CD87932), Color(0x000E0A08)])
              .createShader(
                Rect.fromCircle(
                  center: Offset(size.width * 0.86, size.height * 0.56),
                  radius: size.width * 0.7,
                ),
              );
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AdventureFooterPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mountains = Path()
      ..moveTo(0, size.height * 0.82)
      ..lineTo(size.width * 0.15, size.height * 0.68)
      ..lineTo(size.width * 0.32, size.height * 0.86)
      ..lineTo(size.width * 0.48, size.height * 0.7)
      ..lineTo(size.width * 0.62, size.height * 0.88)
      ..lineTo(size.width * 0.78, size.height * 0.66)
      ..lineTo(size.width, size.height * 0.83)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(mountains, Paint()..color = const Color(0x771D1612));
    canvas.drawCircle(
      Offset(size.width * 0.94, size.height * 0.28),
      9,
      Paint()..color = const Color(0x22E89A4A),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
