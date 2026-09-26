/// Central ride auto-start / auto-end thresholds.
/// Change values here only — tracking logic reads these constants.

/// Trip recording starts only when speed is strictly above this value (km/h).
/// Speed at or below this value must never start a trip.
const double tripStartSpeedKmh = 20.0;

/// Speed must stay above [tripStartSpeedKmh] for this long, using valid GPS
/// samples only, before the app transitions to RIDING.
const Duration tripStartHoldDuration = Duration(seconds: 5);

/// Extra spike guard: require this many consecutive valid samples above
/// [tripStartSpeedKmh] in addition to [tripStartHoldDuration].
const int tripStartMinValidSamples = 4;

/// If valid above-threshold samples are farther apart than this, the start
/// hold resets. Prevents two isolated spikes from looking like sustained speed.
const Duration tripStartMaxSampleGap = Duration(seconds: 2);

/// Horizontal GPS accuracy must be at or below this (meters) for a sample
/// to count toward start or stop decisions. A single inaccurate >20 km/h
/// reading must not start a trip.
const double maxGpsAccuracyMeters = 25.0;

/// Separate from [tripStartSpeedKmh]. The rider may sit in traffic below
/// 20 km/h; the trip ends only after remaining under this stopping speed.
const double tripStopSpeedKmh = 5.0;

/// How long speed must stay below [tripStopSpeedKmh] before the trip ends.
/// Brief stops (signals, congestion) must not end the ride.
const Duration tripStopGracePeriod = Duration(minutes: 3);
