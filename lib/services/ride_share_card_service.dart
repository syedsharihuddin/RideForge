import 'dart:typed_data';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:latlong2/latlong.dart' as ride;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:share_plus/share_plus.dart';

import '../models/ride.dart';
import '../widgets/ride_share_card.dart';

class RideShareCardService {
  const RideShareCardService._();

  static Future<void> share({
    required BuildContext context,
    required Ride ride,
    required Uint8List mapPng,
    required ml.MapLibreMapController mapController,
    required Size mapViewSize,
  }) async {
    final composedMap = await _drawSavedRoute(
      mapPng: mapPng,
      routePoints: ride.routePoints,
      mapController: mapController,
      mapViewSize: mapViewSize,
    );
    if (!context.mounted) return;
    await precacheImage(MemoryImage(composedMap), context);
    if (!context.mounted) return;

    final key = GlobalKey();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -2000,
        top: 0,
        child: RepaintBoundary(
          key: key,
          child: RideShareCard(ride: ride, mapPng: composedMap),
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

  static Future<Uint8List> _drawSavedRoute({
    required Uint8List mapPng,
    required List<ride.LatLng> routePoints,
    required ml.MapLibreMapController mapController,
    required Size mapViewSize,
  }) async {
    final points = routePoints
        .where(_isValidCoordinate)
        .toList(growable: false);
    if (mapViewSize.width <= 0 || mapViewSize.height <= 0) {
      throw StateError('Ride map has an invalid size.');
    }
    final codec = await ui.instantiateImageCodec(mapPng);
    final frame = await codec.getNextFrame();
    final baseMap = frame.image;

    try {
      if (points.isEmpty) return mapPng;

      final projected = await mapController.toScreenLocationBatch(
        points.map((point) => ml.LatLng(point.latitude, point.longitude)),
      );
      final routePixels = projected
          .map(
            (point) => point.x.isFinite && point.y.isFinite
                ? Offset(point.x.toDouble(), point.y.toDouble())
                : null,
          )
          .toList(growable: false);
      if (routePixels.every((point) => point == null)) return mapPng;

      final scaleX = baseMap.width / mapViewSize.width;
      final scaleY = baseMap.height / mapViewSize.height;
      final pixelScale = (scaleX + scaleY) / 2;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final mapBounds = Rect.fromLTWH(
        0,
        0,
        baseMap.width.toDouble(),
        baseMap.height.toDouble(),
      );
      canvas
        ..clipRect(mapBounds)
        ..drawImage(baseMap, Offset.zero, Paint());

      if (routePixels.length >= 2) {
        final routePath = Path();
        var segmentStarted = false;
        for (final point in routePixels) {
          if (point == null) {
            segmentStarted = false;
          } else if (segmentStarted) {
            routePath.lineTo(point.dx, point.dy);
          } else {
            routePath.moveTo(point.dx, point.dy);
            segmentStarted = true;
          }
        }
        canvas.drawPath(
          routePath,
          Paint()
            ..color = const Color(0xFFD6A06A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * pixelScale
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..isAntiAlias = true,
        );
      }

      final start = routePixels.first;
      final end = routePixels.last;
      if (start != null &&
          end != null &&
          (points.length == 1 || _sameCoordinate(points.first, points.last))) {
        // Keep both endpoints visible while anchoring both at the same GPS
        // coordinate for a one-point or closed route.
        _drawEndpoint(
          canvas,
          start,
          const Color(0xFFE05D5D),
          8.5 * pixelScale,
          2 * pixelScale,
        );
        _drawEndpoint(
          canvas,
          end,
          const Color(0xFF46B978),
          4.5 * pixelScale,
          2 * pixelScale,
        );
      } else {
        if (start != null) {
          _drawEndpoint(
            canvas,
            start,
            const Color(0xFFE05D5D),
            7 * pixelScale,
            2 * pixelScale,
          );
        }
        if (end != null) {
          _drawEndpoint(
            canvas,
            end,
            const Color(0xFF46B978),
            7 * pixelScale,
            2 * pixelScale,
          );
        }
      }

      final picture = recorder.endRecording();
      final composedImage = await picture.toImage(
        baseMap.width,
        baseMap.height,
      );
      try {
        final bytes = await composedImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (bytes == null) {
          throw StateError('Could not encode the route map image.');
        }
        return bytes.buffer.asUint8List();
      } finally {
        composedImage.dispose();
        picture.dispose();
      }
    } finally {
      baseMap.dispose();
      codec.dispose();
    }
  }

  static void _drawEndpoint(
    Canvas canvas,
    Offset point,
    Color color,
    double radius,
    double borderWidth,
  ) {
    canvas.drawCircle(
      point,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      point,
      radius - borderWidth,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  static bool _isValidCoordinate(ride.LatLng point) =>
      point.latitude.isFinite &&
      point.longitude.isFinite &&
      point.latitude >= -90 &&
      point.latitude <= 90 &&
      point.longitude >= -180 &&
      point.longitude <= 180;

  static bool _sameCoordinate(ride.LatLng first, ride.LatLng last) =>
      first.latitude == last.latitude && first.longitude == last.longitude;
}
