import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../models/ride.dart';
import '../services/database_service.dart';

class TripDetailsScreen extends StatefulWidget {
  final Ride ride;

  const TripDetailsScreen({
    super.key,
    required this.ride,
  });

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  final MapController _mapController = MapController();

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
    final startLatLng = ride.routePoints.isNotEmpty
        ? ride.routePoints.first
        : const LatLng(17.3850, 78.4867);
    final endLatLng =
        ride.routePoints.isNotEmpty ? ride.routePoints.last : startLatLng;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ride Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
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
            // -----------------------------------------------------------------
            // ROUTE MAP VIEW
            // -----------------------------------------------------------------
            SizedBox(
              height: 320,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: startLatLng,
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.bike',
                  ),
                  if (ride.routePoints.isNotEmpty) ...[
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: ride.routePoints,
                          strokeWidth: 5.0,
                          color: Colors.blueAccent,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // Start Marker
                        Marker(
                          point: startLatLng,
                          width: 36,
                          height: 36,
                          child: const Icon(
                            Icons.trip_origin,
                            color: Colors.greenAccent,
                            size: 28,
                          ),
                        ),
                        // Finish Marker
                        if (ride.routePoints.length > 1)
                          Marker(
                            point: endLatLng,
                            width: 36,
                            height: 36,
                            child: const Icon(
                              Icons.sports_score,
                              color: Colors.redAccent,
                              size: 32,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
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
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
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
                          title: 'Max Speed',
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${ride.routePoints.length} GPS trace points recorded',
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
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
