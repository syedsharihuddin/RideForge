import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' as ride;
import 'package:share_plus/share_plus.dart';

import '../models/ride.dart';
import '../widgets/ride_share_card.dart';

class RideShareCardService {
  const RideShareCardService._();

  static const _snapshotChannel = MethodChannel(
    'com.example.bike/ride_share_map_snapshot',
  );
  static const _snapshotWidth = 1000;
  static const _snapshotHeight = 582;

  /// Creates a share-only map image without the native branding overlays.
  /// The map's required provider credits are printed in the card footer.
  static Future<Uint8List> captureMapSnapshot({
    required List<ride.LatLng> routePoints,
    required String styleUrl,
  }) async {
    final points = routePoints
        .where(_isValidCoordinate)
        .toList(growable: false);
    if (points.isEmpty) {
      throw StateError('Ride has no valid GPS points to share.');
    }

    var minLatitude = points.first.latitude;
    var maxLatitude = minLatitude;
    var minLongitude = points.first.longitude;
    var maxLongitude = minLongitude;
    for (final point in points.skip(1)) {
      minLatitude = math.min(minLatitude, point.latitude);
      maxLatitude = math.max(maxLatitude, point.latitude);
      minLongitude = math.min(minLongitude, point.longitude);
      maxLongitude = math.max(maxLongitude, point.longitude);
    }

    final bytes = await _snapshotChannel.invokeMethod<Uint8List>('capture', {
      'width': _snapshotWidth,
      'height': _snapshotHeight,
      'styleUrl': styleUrl,
      'routePoints': points
          .map((point) => [point.longitude, point.latitude])
          .toList(growable: false),
      'south': minLatitude,
      'north': maxLatitude,
      'west': minLongitude,
      'east': maxLongitude,
    });
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Ride map snapshot could not be generated.');
    }
    return bytes;
  }

  static Future<void> share({
    required BuildContext context,
    required Ride ride,
    required Uint8List mapPng,
  }) async {
    if (!context.mounted) return;
    await precacheImage(MemoryImage(mapPng), context);
    if (!context.mounted) return;

    final key = GlobalKey();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -2000,
        top: 0,
        child: RepaintBoundary(
          key: key,
          child: RideShareCard(ride: ride, mapPng: mapPng),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('Ride share card was not rendered.');
      }

      // The card is 432×540 logical pixels; 2.5× yields a 1080×1350 PNG.
      final image = await renderObject.toImage(pixelRatio: 2.5);
      try {
        final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (pngData == null) {
          throw StateError('Ride share card could not be encoded as PNG.');
        }
        final file = XFile.fromData(
          pngData.buffer.asUint8List(),
          mimeType: 'image/png',
          name: 'rideforge-ride.png',
        );
        await SharePlus.instance.share(
          ShareParams(files: [file], title: 'RideForge Ride'),
        );
      } finally {
        image.dispose();
      }
    } finally {
      entry.remove();
      entry.dispose();
    }
  }

  static bool _isValidCoordinate(ride.LatLng point) =>
      point.latitude.isFinite &&
      point.longitude.isFinite &&
      point.latitude >= -90 &&
      point.latitude <= 90 &&
      point.longitude >= -180 &&
      point.longitude <= 180;
}
