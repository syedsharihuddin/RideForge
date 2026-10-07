import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../config/map_style_config.dart';
import '../models/ride.dart';
import '../services/database_service.dart';
import '../services/ride_share_card_service.dart';
import '../theme/ride_forge_visuals.dart';
import '../widgets/ride_map_widget.dart';

class TripDetailsScreen extends StatefulWidget {
  final Ride ride;

  const TripDetailsScreen({super.key, required this.ride});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  ml.MapLibreMapController? _mapController;
  late final List<LatLng> _validRoutePoints = List.unmodifiable(
    widget.ride.routePoints.where(_isValidCoordinate),
  );
  bool _mapReady = false;
  bool _sharing = false;

  bool _isValidCoordinate(LatLng point) =>
      point.latitude.isFinite &&
      point.longitude.isFinite &&
      point.latitude >= -90 &&
      point.latitude <= 90 &&
      point.longitude >= -180 &&
      point.longitude <= 180;

  void _onMapReady(ml.MapLibreMapController controller) {
    if (!mounted) return;
    setState(() {
      _mapController = controller;
      _mapReady = true;
    });
  }

  Future<void> _shareRide() async {
    final controller = _mapController;
    if (controller == null || _sharing) return;

    setState(() => _sharing = true);
    try {
      // Fit every saved GPS point to the share snapshot's wide viewport.
      final mapPng = await RideShareCardService.captureMapSnapshot(
        routePoints: widget.ride.routePoints,
        styleUrl: MapStyleConfig.lightStyleUrl,
      );
      if (!mounted) return;
      await RideShareCardService.share(
        context: context,
        ride: widget.ride,
        mapPng: mapPng,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share this ride: $error')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Ride?'),
        content: const Text(
          'Are you sure you want to permanently delete this ride from history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.ride.id != null) {
      await DatabaseService.instance.deleteRide(widget.ride.id!);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride deleted successfully.'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, true); // true indicates deletion
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final timeFormat = DateFormat('h:mm a');
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ride Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            tooltip: 'Share Ride',
            onPressed: _mapReady && !_sharing ? _shareRide : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete Ride',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_validRoutePoints.isEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                height: 220,
                decoration: RideForgeVisuals.cardDecoration(highlighted: true),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 34,
                      color: RideForgeVisuals.accent,
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
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                height: 400,
                decoration: RideForgeVisuals.cardDecoration(
                  color: Colors.transparent,
                  radius: 18,
                  highlighted: true,
                ),
                padding: const EdgeInsets.all(1),
                child: RideMapWidget(
                  routePoints: _validRoutePoints,
                  fitRoute: true,
                  showRouteEndpoints: true,
                  showRouteControls: true,
                  captureGestures: true,
                  styleString: MapStyleConfig.lightStyleUrl,
                  onMapReady: _onMapReady,
                ),
              ),
            // -----------------------------------------------------------------
            // DETAILS & STATS
            // -----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date and Time Header
                  Text(
                    ride.formattedDate,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${timeFormat.format(ride.startTime)} - ${timeFormat.format(ride.endTime)}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),

                  const SizedBox(height: 24),

                  // Stat Cards Grid
                  Row(
                    children: [
                      Expanded(
                        child: _detailCard(
                          icon: Icons.route,
                          title: 'Distance',
                          value: '${ride.distance.toStringAsFixed(2)} km',
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _detailCard(
                          icon: Icons.timer,
                          title: 'Duration',
                          value: ride.formattedDuration,
                          color: Colors.lightBlue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _detailCard(
                          icon: Icons.speed,
                          title: 'Avg Speed',
                          value: '${ride.averageSpeed.toStringAsFixed(1)} km/h',
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _detailCard(
                          icon: Icons.flash_on,
                          title: 'Top Speed',
                          value: '${ride.maxSpeed.toStringAsFixed(1)} km/h',
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Route information
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.gps_fixed, color: Colors.blueAccent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Route Accuracy',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_validRoutePoints.length} GPS trace points recorded',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
