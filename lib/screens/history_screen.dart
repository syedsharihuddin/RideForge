import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ride.dart';
import '../services/database_service.dart';
import '../theme/ride_forge_visuals.dart';
import 'trip_details_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    this.loadRides,
    this.deleteRide,
    this.onRideDeleted,
  });

  final Future<List<Ride>> Function()? loadRides;
  final Future<int> Function(int rideId)? deleteRide;
  final VoidCallback? onRideDeleted;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Ride>> _ridesFuture;
  final Map<DateTime, bool> _dateExpansionOverrides = {};

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  void _loadRides() {
    setState(() {
      _ridesFuture =
          widget.loadRides?.call() ?? DatabaseService.instance.getAllRides();
    });
  }

  Future<void> _deleteRide(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this ride?'),
        content: const Text(
          'This ride and its recorded route will be permanently deleted.',
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

    if (confirmed == true) {
      final deletedCount =
          await (widget.deleteRide?.call(id) ??
              DatabaseService.instance.deleteRide(id));
      if (!mounted) return;

      if (deletedCount == 0) {
        _loadRides();
        return;
      }

      widget.onRideDeleted?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride deleted.'),
          duration: Duration(seconds: 2),
        ),
      );
      _loadRides();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ride History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadRides(),
        child: FutureBuilder<List<Ride>>(
          future: _ridesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Error loading rides: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              );
            }

            final rides = snapshot.data ?? [];

            if (rides.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.two_wheeler, size: 72, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No Rides Yet',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Completed rides will be saved and displayed here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final dateGroups = _groupRidesByDate(rides);

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: dateGroups.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final group = dateGroups[index];
                return _buildDateSection(group);
              },
            );
          },
        ),
      ),
    );
  }

  List<_RideDateGroup> _groupRidesByDate(List<Ride> rides) {
    final ridesByDate = <DateTime, List<Ride>>{};
    for (final ride in rides) {
      final date = _dateKey(ride.startTime);
      ridesByDate.putIfAbsent(date, () => <Ride>[]).add(ride);
    }

    final dates = ridesByDate.keys.toList()
      ..sort((first, second) => second.compareTo(first));

    return dates.map((date) {
      final dateRides = ridesByDate[date]!
        ..sort((first, second) => second.startTime.compareTo(first.startTime));
      return _RideDateGroup(date: date, rides: dateRides);
    }).toList();
  }

  DateTime _dateKey(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _isExpanded(DateTime date) {
    final key = _dateKey(date);
    return _dateExpansionOverrides[key] ?? key == _dateKey(DateTime.now());
  }

  void _toggleDate(DateTime date) {
    final key = _dateKey(date);
    setState(() {
      _dateExpansionOverrides[key] = !_isExpanded(key);
    });
  }

  Widget _buildDateSection(_RideDateGroup group) {
    final today = _dateKey(DateTime.now());
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final isToday = group.date == today;
    final isYesterday = group.date == yesterday;
    final expanded = _isExpanded(group.date);

    final title = isToday
        ? 'Today'
        : isYesterday
        ? 'Yesterday'
        : DateFormat('d MMMM yyyy').format(group.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: const Color(0xFF211510),
          elevation: 3,
          shadowColor: RideForgeVisuals.glow.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: RideForgeVisuals.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _toggleDate(group.date),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month,
                    color: Color(0xFFD6A06A),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${DateFormat('d MMMM yyyy').format(group.date)} • '
                          '${group.rides.length} '
                          '${group.rides.length == 1 ? 'ride' : 'rides'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.brown.shade200,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFFD6A06A),
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Column(
            children: expanded
                ? [
                    for (final ride in group.rides)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _buildRideCard(ride),
                      ),
                  ]
                : const [],
          ),
        ),
      ],
    );
  }

  Widget _buildRideCard(Ride ride) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: RideForgeVisuals.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TripDetailsScreen(ride: ride),
            ),
          );
          if (result == true) {
            _loadRides();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Date & delete menu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 15,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ride.formattedDate,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    key: ValueKey('delete-ride-${ride.id}'),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      if (ride.id != null) {
                        _deleteRide(ride.id!);
                      }
                    },
                  ),
                ],
              ),

              const Divider(height: 16),

              // Metrics Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem(
                    label: 'Distance',
                    value: '${ride.distance.toStringAsFixed(2)} km',
                    icon: Icons.route,
                    color: Colors.orange,
                  ),
                  _statItem(
                    label: 'Duration',
                    value: ride.formattedDuration,
                    icon: Icons.timer,
                    color: Colors.lightBlue,
                  ),
                  _statItem(
                    label: 'Avg Speed',
                    value: '${ride.averageSpeed.toStringAsFixed(1)} km/h',
                    icon: Icons.speed,
                    color: Colors.green,
                  ),
                  _statItem(
                    label: 'Top Speed',
                    value: '${ride.maxSpeed.toStringAsFixed(1)} km/h',
                    icon: Icons.flash_on,
                    color: Colors.amber,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _RideDateGroup {
  final DateTime date;
  final List<Ride> rides;

  const _RideDateGroup({required this.date, required this.rides});
}
