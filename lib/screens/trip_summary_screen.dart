import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/ride.dart';
import '../services/database_service.dart';

class TripSummaryScreen extends StatefulWidget {
  final double distance;
  final Duration duration;
  final double averageSpeed;
  final double maxSpeed;
  final DateTime startTime;
  final DateTime endTime;
  final List<LatLng> routePoints;

  const TripSummaryScreen({
    super.key,
    required this.distance,
    required this.duration,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.startTime,
    required this.endTime,
    this.routePoints = const [],
  });

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> {
  bool _isSaving = false;

  // ============================================================
  // THEME COLORS
  // ============================================================

  static const Color brownAccent = Color(0xFFB8754D);
  static const Color goldAccent = Color(0xFFD6A06A);
  static const Color lightText = Color(0xFFF5EDE7);
  static const Color secondaryText = Color(0xFFB9AAA2);
  static const Color cardBorder = Color(0xFF3B2820);

  // ============================================================
  // FORMAT DURATION
  // ============================================================

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // SAVE RIDE
  // ============================================================

  Future<void> _saveRide() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final ride = Ride(
        startTime: widget.startTime,
        endTime: widget.endTime,
        distance: widget.distance,
        durationSeconds: widget.duration.inSeconds,
        averageSpeed: widget.averageSpeed,
        maxSpeed: widget.maxSpeed,
        routePoints: widget.routePoints,
      );

      await DatabaseService.instance.insertRide(ride);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF6F513D),
          behavior: SnackBarBehavior.floating,

          content: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Color(0xFFD6A06A),
              ),
              SizedBox(width: 12),

              Text(
                'Ride saved successfully!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          duration: Duration(seconds: 2),
        ),
      );

      Navigator.popUntil(
        context,
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF7A3F36),
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Failed to save ride: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DISCARD RIDE
  // ============================================================

  Future<void> _confirmDiscard() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,

      builder: (context) => AlertDialog(
        title: const Text(
          'Discard Ride?',
        ),

        content: const Text(
          'Are you sure you want to discard this ride? '
          'The recorded tracking data will be lost permanently.',
        ),

        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),

            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: goldAccent,
              ),
            ),
          ),

          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Color(0xFFD96C5F),
            ),

            onPressed: () =>
                Navigator.pop(context, true),

            child: const Text(
              'DISCARD',
            ),
          ),
        ],
      ),
    );

    if (shouldDiscard == true && mounted) {
      Navigator.popUntil(
        context,
        (route) => route.isFirst,
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final dateFormat =
        DateFormat('EEE, d MMM yyyy • h:mm a');

    final formattedStartTime =
        dateFormat.format(widget.startTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ride Summary',

          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        automaticallyImplyLeading: false,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            const SizedBox(height: 10),

            // ==========================================================
            // COMPLETED RIDE ICON
            // ==========================================================

            Container(
              width: 80,
              height: 80,

              decoration: BoxDecoration(
                color: brownAccent.withValues(alpha: 0.18),
                shape: BoxShape.circle,

                border: Border.all(
                  color: brownAccent.withValues(alpha: 0.4),
                  width: 1.5,
                ),

                boxShadow: [
                  BoxShadow(
                    color: brownAccent.withValues(alpha: 0.15),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),

              child: const Icon(
                Icons.flag,
                size: 42,
                color: goldAccent,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Ride Complete!',

              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: lightText,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              formattedStartTime,

              style: const TextStyle(
                fontSize: 14,
                color: secondaryText,
              ),
            ),

            const SizedBox(height: 30),

            // ==========================================================
            // FIRST ROW OF STATS
            // ==========================================================

            Row(
              children: [
                Expanded(
                  child: _statCard(
                    Icons.route,
                    widget.distance.toStringAsFixed(2),
                    'Distance (km)',
                    goldAccent,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _statCard(
                    Icons.timer,
                    _formatDuration(widget.duration),
                    'Duration',
                    brownAccent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ==========================================================
            // SECOND ROW OF STATS
            // ==========================================================

            Row(
              children: [
                Expanded(
                  child: _statCard(
                    Icons.speed,
                    widget.averageSpeed.toStringAsFixed(1),
                    'Avg Speed (km/h)',
                    const Color(0xFFC98B5B),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _statCard(
                    Icons.flash_on,
                    widget.maxSpeed.toStringAsFixed(1),
                    'Max Speed (km/h)',
                    const Color(0xFFE0B078),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ==========================================================
            // GPS POINTS BADGE
            // ==========================================================

            if (widget.routePoints.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),

                decoration: BoxDecoration(
                  color: const Color(0xFF211510),

                  borderRadius:
                      BorderRadius.circular(20),

                  border: Border.all(
                    color: cardBorder,
                  ),
                ),

                child: Row(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: goldAccent,
                    ),

                    const SizedBox(width: 6),

                    Text(
                      '${widget.routePoints.length} GPS points recorded',

                      style: const TextStyle(
                        fontSize: 13,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 35),

            // ==========================================================
            // SAVE RIDE
            // ==========================================================

            SizedBox(
              width: double.infinity,
              height: 58,

              child: ElevatedButton.icon(
                onPressed:
                    _isSaving ? null : _saveRide,

                icon: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,

                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.save,
                      ),

                label: Text(
                  _isSaving
                      ? 'SAVING RIDE...'
                      : 'SAVE RIDE',

                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ==========================================================
            // DISCARD RIDE
            // ==========================================================

            SizedBox(
              width: double.infinity,
              height: 52,

              child: OutlinedButton(
                onPressed:
                    _isSaving ? null : _confirmDiscard,

                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      const Color(0xFFD96C5F),

                  side: const BorderSide(
                    color: Color(0xFF7A443D),
                    width: 1.2,
                  ),

                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                ),

                child: const Text(
                  'DISCARD RIDE',

                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD96C5F),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _statCard(
    IconData icon,
    String value,
    String label,
    Color iconColor,
  ) {
    return Card(
      elevation: 0,

      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: iconColor,
            ),

            const SizedBox(height: 10),

            Text(
              value,

              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: lightText,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              label,

              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 12,
                color: secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}