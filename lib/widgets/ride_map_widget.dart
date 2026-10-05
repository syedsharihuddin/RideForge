import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ride;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../config/map_style_config.dart';

/// Displays RideForge coordinates without owning or requesting GPS updates.
class RideMapWidget extends StatefulWidget {
  const RideMapWidget({
    super.key,
    required this.routePoints,
    this.routeGroups,
    this.currentLocation,
    this.currentLocationTimestamp,
    this.currentLocationAccuracyMeters,
    this.followLocation = false,
    this.fitRoute = false,
    this.showRouteEndpoints = false,
    this.showRouteControls = false,
    this.showRecenterButton = false,
    this.captureGestures = false,
    this.initialZoom = 15,
    this.initialCameraTarget,
    this.styleString,
    this.onMapReady,
    this.onRecenter,
  });

  final List<ride.LatLng> routePoints;

  /// Multiple saved rides to draw together. When provided, [routePoints] is
  /// ignored and every ride receives its own route and endpoint markers.
  final List<List<ride.LatLng>>? routeGroups;
  final ride.LatLng? currentLocation;
  final DateTime? currentLocationTimestamp;
  final double? currentLocationAccuracyMeters;
  final bool followLocation;
  final bool fitRoute;
  final bool showRouteEndpoints;
  final bool showRouteControls;
  final bool showRecenterButton;
  final bool captureGestures;
  final double initialZoom;
  final ride.LatLng? initialCameraTarget;
  final String? styleString;

  /// Called after the style, route annotations, and initial camera are ready.
  final ValueChanged<ml.MapLibreMapController>? onMapReady;
  final VoidCallback? onRecenter;

  @override
  State<RideMapWidget> createState() => _RideMapWidgetState();
}

class _RideMapWidgetState extends State<RideMapWidget> {
  static const _routeColor = '#D6A06A';
  static const _riderColor = '#FFD166';
  static const _startColor = '#46B978';
  static const _endColor = '#E05D5D';

  ml.MapLibreMapController? _controller;
  ml.Line? _routeLine;
  final List<ml.Line> _journeyLines = [];
  final List<ml.Circle> _journeyMarkers = [];
  ml.Circle? _riderMarker;
  ml.Circle? _startMarker;
  ml.Circle? _endMarker;
  List<ride.LatLng> _validRoute = const [];
  ml.LatLngBounds? _routeBounds;
  List<ride.LatLng> _lastRoute = const [];
  ride.LatLng? _lastLocation;
  bool _styleLoaded = false;
  bool _syncing = false;
  bool _syncPending = false;
  bool _fitPending = false;
  bool _fittedInitialRoute = false;
  bool _mapBecameIdle = false;
  bool _mapLoadTimedOut = false;
  Timer? _mapLoadTimer;

  @override
  void initState() {
    super.initState();
    _refreshRouteCache();
    _mapLoadTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || _mapBecameIdle) return;
      setState(() => _mapLoadTimedOut = true);
    });
  }

  void _onMapIdle() {
    _mapLoadTimer?.cancel();
    if (!_mapBecameIdle && mounted) {
      setState(() => _mapBecameIdle = true);
    }
  }

  @override
  void dispose() {
    _mapLoadTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RideMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final locationChanged =
        oldWidget.currentLocation != widget.currentLocation ||
        oldWidget.currentLocationAccuracyMeters !=
            widget.currentLocationAccuracyMeters ||
        _validCurrentLocation() != _lastLocation;
    final routeChanged =
        !listEquals(oldWidget.routePoints, widget.routePoints) ||
        !_sameRouteGroups(oldWidget.routeGroups, widget.routeGroups);
    if (routeChanged) _refreshRouteCache();
    final optionsChanged =
        oldWidget.showRouteEndpoints != widget.showRouteEndpoints ||
        oldWidget.followLocation != widget.followLocation ||
        oldWidget.fitRoute != widget.fitRoute;

    if (_styleLoaded && (locationChanged || routeChanged || optionsChanged)) {
      _syncMapData(
        routeChanged: routeChanged,
        locationChanged: locationChanged,
        fitRoute: widget.fitRoute && !_fittedInitialRoute,
      );
    }
  }

  void _onMapCreated(ml.MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;

    _styleLoaded = true;
    _routeLine = null;
    _riderMarker = null;
    _startMarker = null;
    _endMarker = null;
    _journeyLines.clear();
    _journeyMarkers.clear();
    _lastRoute = const [];
    _lastLocation = null;

    await _syncMapData(
      routeChanged: true,
      locationChanged: true,
      fitRoute: widget.fitRoute,
    );
    if (mounted) widget.onMapReady?.call(controller);
  }

  Future<void> _syncMapData({
    required bool routeChanged,
    required bool locationChanged,
    required bool fitRoute,
  }) async {
    if (_syncing) {
      _syncPending = true;
      _fitPending = _fitPending || fitRoute;
      return;
    }

    _syncing = true;
    var updateRoute = routeChanged;
    var updateLocation = locationChanged;
    var shouldFitRoute = fitRoute;

    try {
      do {
        _syncPending = false;
        await _syncOnce(
          routeChanged: updateRoute,
          locationChanged: updateLocation,
          fitRoute: shouldFitRoute || _fitPending,
        );
        updateRoute = true;
        updateLocation = true;
        shouldFitRoute = false;
        _fitPending = false;
      } while (_syncPending && mounted);
    } catch (error) {
      debugPrint('[RideMap] Map data update failed: $error');
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncOnce({
    required bool routeChanged,
    required bool locationChanged,
    required bool fitRoute,
  }) async {
    final controller = _controller;
    if (!_styleLoaded || controller == null) return;

    final route = _validRoute;
    final routeDidChange = routeChanged || !listEquals(route, _lastRoute);
    final location = _validCurrentLocation();
    final locationDidChange = locationChanged || location != _lastLocation;

    if (routeDidChange) {
      if (widget.routeGroups != null) {
        await _syncJourneyRoutes(controller);
      } else if (route.length >= 2) {
        final options = ml.LineOptions(
          geometry: route.map(_toMapLibre).toList(growable: false),
          lineColor: _routeColor,
          lineWidth: 5,
          lineOpacity: 0.95,
        );
        final currentLine = _routeLine;
        if (currentLine == null) {
          _routeLine = await controller.addLine(options);
        } else {
          await controller.updateLine(currentLine, options);
        }
      } else if (_routeLine != null) {
        await controller.removeLine(_routeLine!);
        _routeLine = null;
      }

      _lastRoute = List.unmodifiable(route);
      if (widget.routeGroups == null) {
        await _syncEndpointMarkers(controller, route);
      }
    }

    if (locationDidChange) {
      if (location == null) {
        if (_riderMarker != null) {
          await controller.removeCircle(_riderMarker!);
          _riderMarker = null;
        }
      } else {
        final options = ml.CircleOptions(
          geometry: _toMapLibre(location),
          circleColor: _riderColor,
          circleRadius: 8,
          circleStrokeColor: '#211510',
          circleStrokeWidth: 3,
        );
        final currentMarker = _riderMarker;
        if (currentMarker == null) {
          _riderMarker = await controller.addCircle(options);
        } else {
          await controller.updateCircle(currentMarker, options);
        }

        if (widget.followLocation && location != _lastLocation) {
          await controller.animateCamera(
            ml.CameraUpdate.newLatLng(_toMapLibre(location)),
            duration: const Duration(milliseconds: 350),
          );
        }
      }
      _lastLocation = location;
    }

    if (fitRoute && !_fittedInitialRoute && route.isNotEmpty) {
      if (widget.routeGroups != null) {
        await _fitPoints(controller, route);
      } else {
        await _fitRoute(controller, route);
      }
      _fittedInitialRoute = true;
    }
  }

  Future<void> _syncJourneyRoutes(ml.MapLibreMapController controller) async {
    for (final line in _journeyLines) {
      await controller.removeLine(line);
    }
    _journeyLines.clear();
    for (final marker in _journeyMarkers) {
      await controller.removeCircle(marker);
    }
    _journeyMarkers.clear();

    final groups = (widget.routeGroups ?? const <List<ride.LatLng>>[])
        .map((points) => _validRoutePoints(points))
        .where((points) => points.isNotEmpty);
    const colors = ['#D6A06A', '#FFD166', '#E89B5A', '#C98759'];
    for (final (index, route) in groups.indexed) {
      if (route.length >= 2) {
        _journeyLines.add(
          await controller.addLine(
            ml.LineOptions(
              geometry: route.map(_toMapLibre).toList(growable: false),
              lineColor: colors[index % colors.length],
              lineWidth: 5,
              lineOpacity: 0.95,
            ),
          ),
        );
      }
      if (route.isNotEmpty) {
        _journeyMarkers.add(
          await controller.addCircle(
            ml.CircleOptions(
              geometry: _toMapLibre(route.first),
              circleColor: _startColor,
              circleRadius: 8,
              circleStrokeColor: '#FFFFFF',
              circleStrokeWidth: 2,
            ),
          ),
        );
        _journeyMarkers.add(
          await controller.addCircle(
            ml.CircleOptions(
              geometry: _toMapLibre(route.last),
              circleColor: _endColor,
              circleRadius: 8,
              circleStrokeColor: '#FFFFFF',
              circleStrokeWidth: 2,
            ),
          ),
        );
      }
    }
  }

  Future<void> _fitPoints(
    ml.MapLibreMapController controller,
    List<ride.LatLng> points,
  ) async {
    if (points.length == 1) {
      await controller.animateCamera(
        ml.CameraUpdate.newLatLngZoom(_toMapLibre(points.single), 15),
        duration: const Duration(milliseconds: 400),
      );
      return;
    }
    var south = points.first.latitude;
    var north = south;
    var west = points.first.longitude;
    var east = west;
    for (final point in points.skip(1)) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }
    if (south == north && west == east) {
      await controller.animateCamera(
        ml.CameraUpdate.newLatLngZoom(_toMapLibre(points.first), 15),
        duration: const Duration(milliseconds: 400),
      );
      return;
    }
    await controller.animateCamera(
      ml.CameraUpdate.newLatLngBounds(
        ml.LatLngBounds(
          southwest: ml.LatLng(south, west),
          northeast: ml.LatLng(north, east),
        ),
        left: 48,
        top: 48,
        right: 48,
        bottom: 48,
      ),
      duration: const Duration(milliseconds: 400),
    );
  }

  bool _sameRouteGroups(
    List<List<ride.LatLng>>? first,
    List<List<ride.LatLng>>? second,
  ) {
    if (identical(first, second)) return true;
    if (first == null || second == null || first.length != second.length) {
      return false;
    }
    for (var i = 0; i < first.length; i++) {
      if (!listEquals(first[i], second[i])) return false;
    }
    return true;
  }

  Future<void> _syncEndpointMarkers(
    ml.MapLibreMapController controller,
    List<ride.LatLng> route,
  ) async {
    if (!widget.showRouteEndpoints || route.isEmpty) {
      if (_startMarker != null) {
        await controller.removeCircle(_startMarker!);
        _startMarker = null;
      }
      if (_endMarker != null) {
        await controller.removeCircle(_endMarker!);
        _endMarker = null;
      }
      return;
    }

    final start = ml.CircleOptions(
      geometry: _toMapLibre(route.first),
      circleColor: _startColor,
      circleRadius: 7,
      circleStrokeColor: '#FFFFFF',
      circleStrokeWidth: 2,
    );
    if (_startMarker == null) {
      _startMarker = await controller.addCircle(start);
    } else {
      await controller.updateCircle(_startMarker!, start);
    }

    final end = ml.CircleOptions(
      geometry: _toMapLibre(route.last),
      circleColor: _endColor,
      circleRadius: route.length == 1 ? 3 : 7,
      circleStrokeColor: '#FFFFFF',
      circleStrokeWidth: route.length == 1 ? 1 : 2,
    );
    if (_endMarker == null) {
      _endMarker = await controller.addCircle(end);
    } else {
      await controller.updateCircle(_endMarker!, end);
    }
  }

  Future<void> _fitRoute(
    ml.MapLibreMapController controller,
    List<ride.LatLng> route,
  ) async {
    if (route.length == 1) {
      await controller.animateCamera(
        ml.CameraUpdate.newLatLngZoom(_toMapLibre(route.single), 16),
        duration: const Duration(milliseconds: 400),
      );
      return;
    }

    final bounds = _routeBounds;
    if (bounds == null ||
        (bounds.southwest.latitude == bounds.northeast.latitude &&
            bounds.southwest.longitude == bounds.northeast.longitude)) {
      await controller.animateCamera(
        ml.CameraUpdate.newLatLngZoom(_toMapLibre(route.first), 16),
        duration: const Duration(milliseconds: 400),
      );
      return;
    }

    await controller.animateCamera(
      ml.CameraUpdate.newLatLngBounds(
        bounds,
        left: 44,
        top: 44,
        right: 44,
        bottom: 44,
      ),
      duration: const Duration(milliseconds: 400),
    );
  }

  void _refreshRouteCache() {
    final groups = widget.routeGroups;
    final points = groups == null
        ? widget.routePoints
        : groups.expand((group) => group).toList(growable: false);
    _validRoute = List.unmodifiable(_validRoutePoints(points));
    if (_validRoute.isEmpty) {
      _routeBounds = null;
      return;
    }

    var minLatitude = _validRoute.first.latitude;
    var maxLatitude = minLatitude;
    var minLongitude = _validRoute.first.longitude;
    var maxLongitude = minLongitude;
    for (final point in _validRoute.skip(1)) {
      if (point.latitude < minLatitude) minLatitude = point.latitude;
      if (point.latitude > maxLatitude) maxLatitude = point.latitude;
      if (point.longitude < minLongitude) minLongitude = point.longitude;
      if (point.longitude > maxLongitude) maxLongitude = point.longitude;
    }
    _routeBounds = ml.LatLngBounds(
      southwest: ml.LatLng(minLatitude, minLongitude),
      northeast: ml.LatLng(maxLatitude, maxLongitude),
    );
  }

  Future<void> _fitSavedRoute() async {
    final controller = _controller;
    if (controller == null) return;

    final route = _lastRoute;
    if (route.isNotEmpty) {
      await _fitRoute(controller, route);
    }
  }

  Future<void> _zoomIn() async {
    await _controller?.animateCamera(
      ml.CameraUpdate.zoomIn(),
      duration: const Duration(milliseconds: 180),
    );
  }

  Future<void> _zoomOut() async {
    await _controller?.animateCamera(
      ml.CameraUpdate.zoomOut(),
      duration: const Duration(milliseconds: 180),
    );
  }

  List<ride.LatLng> _validRoutePoints(List<ride.LatLng> points) =>
      points.where(_isValidCoordinate).toList(growable: false);

  ride.LatLng? _validCurrentLocation() {
    final location = widget.currentLocation;
    if (location == null || !_isValidCoordinate(location)) return null;
    if (widget.currentLocationAccuracyMeters != null &&
        widget.currentLocationAccuracyMeters! > 100) {
      return null;
    }
    final timestamp = widget.currentLocationTimestamp;
    if (timestamp != null) {
      final age = DateTime.now().difference(timestamp);
      if (age > const Duration(minutes: 2) ||
          age < const Duration(seconds: -30)) {
        return null;
      }
    }
    return location;
  }

  bool _isValidCoordinate(ride.LatLng point) =>
      point.latitude.isFinite &&
      point.longitude.isFinite &&
      point.latitude >= -90 &&
      point.latitude <= 90 &&
      point.longitude >= -180 &&
      point.longitude <= 180;

  ml.LatLng _toMapLibre(ride.LatLng point) =>
      ml.LatLng(point.latitude, point.longitude);

  Future<void> _recenterOnCurrentLocation() async {
    final location = _validCurrentLocation();
    final controller = _controller;
    if (location == null || controller == null) return;

    await controller.animateCamera(
      ml.CameraUpdate.newLatLngZoom(_toMapLibre(location), 15),
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final validLocation = _validCurrentLocation();
    final route = _validRoute;
    final initialCenter =
        widget.initialCameraTarget ??
        validLocation ??
        (route.isNotEmpty ? route.first : null) ??
        const ride.LatLng(17.3850, 78.4867);

    final map = ml.MapLibreMap(
      initialCameraPosition: ml.CameraPosition(
        target: _toMapLibre(initialCenter),
        zoom: widget.initialZoom,
      ),
      styleString:
          widget.styleString ??
          (theme.brightness == Brightness.dark
              ? MapStyleConfig.darkStyleUrl
              : MapStyleConfig.lightStyleUrl),
      compassEnabled: true,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled: true,
      gestureRecognizers: widget.captureGestures
          ? <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            }
          : null,
      myLocationEnabled: false,
      attributionButtonPosition: ml.AttributionButtonPosition.bottomRight,
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      onMapIdle: _onMapIdle,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: !widget.showRecenterButton && !widget.showRouteControls
          ? map
          : Stack(
              fit: StackFit.expand,
              children: [
                map,
                if (_mapLoadTimedOut && !_mapBecameIdle)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF211510).withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF3B2820)),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          'Map tiles are taking too long to load. Check your internet connection.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                if (widget.showRouteControls && widget.showRouteEndpoints)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF211510).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3B2820)),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow,
                              size: 16,
                              color: Color(0xFF46B978),
                            ),
                            SizedBox(width: 3),
                            Text(
                              'START',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(
                              Icons.flag,
                              size: 15,
                              color: Color(0xFFE05D5D),
                            ),
                            SizedBox(width: 3),
                            Text(
                              'FINISH',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (widget.showRouteControls)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Material(
                      color: const Color(0xFF211510).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _zoomIn,
                            tooltip: 'Zoom in',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.add,
                              color: Color(0xFFF5EDE7),
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFF3B2820)),
                          IconButton(
                            onPressed: _zoomOut,
                            tooltip: 'Zoom out',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.remove,
                              color: Color(0xFFF5EDE7),
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFF3B2820)),
                          IconButton(
                            onPressed: _fitSavedRoute,
                            tooltip: 'Fit route',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.fit_screen,
                              color: Color(0xFFD6A06A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (widget.showRecenterButton)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Material(
                      color: const Color(0xFF211510).withValues(alpha: 0.9),
                      shape: const CircleBorder(
                        side: BorderSide(color: Color(0xFF3B2820)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        onPressed:
                            widget.onRecenter ?? _recenterOnCurrentLocation,
                        tooltip: 'Current location',
                        icon: const Icon(
                          Icons.my_location,
                          color: Color(0xFFD6A06A),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
