import '../config/ride_thresholds.dart';

enum RidePhase {
  detecting,
  riding,
}

enum AutoRideSignal {
  none,
  tripStarted,
  tripEnded,
}

/// Decides automatic trip start/end from GPS speed + accuracy.
///
/// Start: speed must be **greater than** [tripStartSpeedKmh], accuracy must be
/// good, and that must hold for [tripStartHoldDuration] with enough samples.
/// End: speed below [tripStopSpeedKmh] for [tripStopGracePeriod] — never
/// merely because speed dropped below the 20 km/h start threshold.
class AutoRideGate {
  RidePhase phase = RidePhase.detecting;

  DateTime? _startHoldBeganAt;
  DateTime? _lastValidHighSpeedAt;
  int _startValidSampleCount = 0;

  DateTime? _stopHoldBeganAt;

  bool get isRiding => phase == RidePhase.riding;
  bool get isDetecting => phase == RidePhase.detecting;

  DateTime? get stopHoldBeganAt => _stopHoldBeganAt;

  double startHoldProgress(DateTime now) {
    if (phase != RidePhase.detecting || _startHoldBeganAt == null) {
      return 0.0;
    }
    final elapsed = now.difference(_startHoldBeganAt!);
    final t = elapsed.inMilliseconds / tripStartHoldDuration.inMilliseconds;
    if (t <= 0) return 0.0;
    if (t >= 1) return 1.0;
    return t;
  }

  Duration? stopGraceRemaining(DateTime now) {
    if (phase != RidePhase.riding || _stopHoldBeganAt == null) {
      return null;
    }
    final remaining = tripStopGracePeriod - now.difference(_stopHoldBeganAt!);
    if (remaining.isNegative) return Duration.zero;
    return remaining;
  }

  /// Ingest one GPS sample. Inaccurate readings never start a trip and do
  /// not extend the start hold.
  AutoRideSignal ingest({
    required DateTime now,
    required double speedKmh,
    required double accuracyMeters,
  }) {
    if (accuracyMeters > maxGpsAccuracyMeters) {
      if (phase == RidePhase.detecting) {
        _resetStartHold();
      }
      return AutoRideSignal.none;
    }

    if (phase == RidePhase.detecting) {
      return _ingestDetecting(now: now, speedKmh: speedKmh);
    }

    _ingestRiding(now: now, speedKmh: speedKmh);
    return AutoRideSignal.none;
  }

  /// Call on a 1s tick so a parked bike (no GPS movement callbacks) can
  /// still end the trip after the grace period.
  AutoRideSignal checkTimeout(DateTime now) {
    if (phase != RidePhase.riding || _stopHoldBeganAt == null) {
      return AutoRideSignal.none;
    }
    if (now.difference(_stopHoldBeganAt!) >= tripStopGracePeriod) {
      return AutoRideSignal.tripEnded;
    }
    return AutoRideSignal.none;
  }

  AutoRideSignal _ingestDetecting({
    required DateTime now,
    required double speedKmh,
  }) {
    if (speedKmh > tripStartSpeedKmh) {
      if (_lastValidHighSpeedAt != null &&
          now.difference(_lastValidHighSpeedAt!) > tripStartMaxSampleGap) {
        _resetStartHold();
      }

      _startHoldBeganAt ??= now;
      _lastValidHighSpeedAt = now;
      _startValidSampleCount++;

      final heldLongEnough =
          now.difference(_startHoldBeganAt!) >= tripStartHoldDuration;
      final enoughSamples =
          _startValidSampleCount >= tripStartMinValidSamples;

      if (heldLongEnough && enoughSamples) {
        phase = RidePhase.riding;
        _stopHoldBeganAt = null;
        _resetStartHold();
        return AutoRideSignal.tripStarted;
      }

      return AutoRideSignal.none;
    }

    _resetStartHold();
    return AutoRideSignal.none;
  }

  void _ingestRiding({
    required DateTime now,
    required double speedKmh,
  }) {
    if (speedKmh < tripStopSpeedKmh) {
      _stopHoldBeganAt ??= now;
    } else {
      _stopHoldBeganAt = null;
    }
  }

  void _resetStartHold() {
    _startHoldBeganAt = null;
    _lastValidHighSpeedAt = null;
    _startValidSampleCount = 0;
  }
}
