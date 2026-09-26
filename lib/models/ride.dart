import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

class Ride {
  final int? id;
  final DateTime startTime;
  final DateTime endTime;
  final double distance; // in km
  final int durationSeconds;
  final double averageSpeed; // in km/h
  final double maxSpeed; // in km/h
  final List<LatLng> routePoints;

  Ride({
    this.id,
    required this.startTime,
    required this.endTime,
    required this.distance,
    required this.durationSeconds,
    required this.averageSpeed,
    required this.maxSpeed,
    this.routePoints = const [],
  });

  Duration get duration => Duration(seconds: durationSeconds);

  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedDate {
    return DateFormat('EEE, d MMM yyyy • h:mm a').format(startTime);
  }

  Map<String, dynamic> toMap() {
    final pointsJson = jsonEncode(
      routePoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    );

    return {
      'id': id,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'distance': distance,
      'duration_seconds': durationSeconds,
      'average_speed': averageSpeed,
      'max_speed': maxSpeed,
      'route_points': pointsJson,
    };
  }

  factory Ride.fromMap(Map<String, dynamic> map) {
    List<LatLng> points = [];
    if (map['route_points'] != null &&
        map['route_points'].toString().isNotEmpty) {
      try {
        final decoded =
            jsonDecode(map['route_points'] as String) as List<dynamic>;
        points = decoded.map((item) {
          final lat = (item['lat'] as num).toDouble();
          final lng = (item['lng'] as num).toDouble();
          return LatLng(lat, lng);
        }).toList();
      } catch (_) {
        points = [];
      }
    }

    return Ride(
      id: map['id'] as int?,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: DateTime.parse(map['end_time'] as String),
      distance: (map['distance'] as num).toDouble(),
      durationSeconds: map['duration_seconds'] as int,
      averageSpeed: (map['average_speed'] as num).toDouble(),
      maxSpeed: (map['max_speed'] as num).toDouble(),
      routePoints: points,
    );
  }
}
