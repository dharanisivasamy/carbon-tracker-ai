import 'dart:async';
import 'dart:math' as math;

import 'gps_service.dart';
import 'ml_trip_classifier.dart';

/// Kept separate from persistence/UI so a trained model can replace it later.
enum DetectedTravelMode { stationary, walking, cycling, vehicle }

/// Pure Review-1 classifier. Input is kilometres per hour.
DetectedTravelMode classifySpeedKmh(double speedKmh) {
  if (speedKmh < 2) return DetectedTravelMode.stationary;
  if (speedKmh < 7) return DetectedTravelMode.walking;
  if (speedKmh <= 20) return DetectedTravelMode.cycling;
  return DetectedTravelMode.vehicle;
}

class DetectedTrip {
  const DetectedTrip({required this.id, required this.distanceKm, required this.mode, required this.startedAt, required this.endedAt, required this.featureWindow});
  final String id;
  final double distanceKm;
  final DetectedTravelMode mode;
  final DateTime startedAt;
  final DateTime endedAt;
  final DetectedFeatureWindow featureWindow;
}

class DetectedFeatureWindow {
  const DetectedFeatureWindow({required this.avgSpeedKmh, required this.speedVarianceKmh2, required this.maxSpeedKmh, required this.distanceM, required this.gpsPoints});
  final double avgSpeedKmh, speedVarianceKmh2, maxSpeedKmh, distanceM;
  final List<Map<String, dynamic>> gpsPoints;
  Map<String, dynamic> toJson() => {'avgSpeedKmh': avgSpeedKmh, 'speedVarianceKmh2': speedVarianceKmh2, 'maxSpeedKmh': maxSpeedKmh, 'distanceM': distanceM, 'gpsPoints': gpsPoints};
}

class AutoTripDetector {
  // Judgment call: tune after physical-device field tests.
  static const Duration stationaryTimeout = Duration(minutes: 3);
  // Judgment call: ignore a new mode until it lasts five seconds, rejecting GPS spikes.
  static const Duration modeChangeConfirmation = Duration(seconds: 5);
  final GpsService _gps;
  final MlTripClassifier _mlClassifier;
  final _completedTrips = StreamController<DetectedTrip>.broadcast();
  final _activeTrips = StreamController<DetectedTrip?>.broadcast();
  StreamSubscription<GpsSample>? _subscription;
  GpsSample? _previous;
  DateTime? _startedAt, _stationarySince, _pendingSince;
  double _distanceMetres = 0;
  final Map<DetectedTravelMode, Duration> _modeDurations = {};
  DetectedTravelMode? _acceptedMode, _pendingMode;
  final List<_SpeedObservation> _speedWindow = [];
  final List<_SpeedObservation> _tripSpeedObservations = [];
  final List<Map<String, dynamic>> _tripGpsPoints = [];
  DateTime? _lastMlRequest;
  DetectedTravelMode? _lastMlPrediction;
  Stream<DetectedTrip> get completedTrips => _completedTrips.stream;
  Stream<DetectedTrip?> get activeTrips => _activeTrips.stream;
  bool get isListening => _subscription != null;

  AutoTripDetector(this._gps, {MlTripClassifier? mlClassifier}) : _mlClassifier = mlClassifier ?? MlTripClassifier();

  Future<GpsStartResult> start() async {
    final result = await _gps.start();
    if (result == GpsStartResult.started && !isListening) _subscription = _gps.samples.listen(_onSample, onError: _completedTrips.addError);
    return result;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _reset();
    await _gps.stop();
  }

  void _onSample(GpsSample sample) {
    final previous = _previous;
    _previous = sample;
    if (previous == null) return;
    final elapsed = sample.timestamp.difference(previous.timestamp);
    if (elapsed <= Duration.zero || elapsed > const Duration(minutes: 2)) return;
    // Once available, ML drives classification. Until then (or after any ML
    // failure) the exact Review-1 speed rule is the automatic fallback.
    final rawMode = _lastMlPrediction ?? classifySpeedKmh(sample.speedKilometresPerHour);
    _addSpeedObservation(sample, previous);
    if (_startedAt != null) _recordTripPoint(sample, previous);
    _requestMlClassification(sample.timestamp);
    if (_startedAt == null) {
      if (rawMode != DetectedTravelMode.stationary) _begin(sample, rawMode);
      return;
    }
    final meters = _distanceBetween(previous, sample);
    if (meters >= 3 && meters <= 2000) _distanceMetres += meters;
    if (rawMode == DetectedTravelMode.stationary) {
      _stationarySince ??= sample.timestamp;
      if (sample.timestamp.difference(_stationarySince!) >= stationaryTimeout) _complete(sample.timestamp);
      return;
    }
    _stationarySince = null;
    _acceptModeAfterNoiseFilter(rawMode, sample.timestamp, elapsed);
    _emitActive(sample.timestamp);
  }

  void _addSpeedObservation(GpsSample sample, GpsSample previous) {
    _speedWindow.add(_SpeedObservation(sample.timestamp, sample.speedKilometresPerHour, _distanceBetween(previous, sample)));
    _speedWindow.removeWhere((item) => sample.timestamp.difference(item.timestamp) > const Duration(seconds: 5));
  }

  void _recordTripPoint(GpsSample sample, GpsSample previous) {
    _tripSpeedObservations.add(_SpeedObservation(sample.timestamp, sample.speedKilometresPerHour, _distanceBetween(previous, sample)));
    _tripGpsPoints.add({'latitude': sample.latitude, 'longitude': sample.longitude, 'speedMps': sample.speedMetresPerSecond, 'timestamp': sample.timestamp.toIso8601String()});
  }

  void _requestMlClassification(DateTime time) {
    if (!useMlClassifier || (_lastMlRequest != null && time.difference(_lastMlRequest!) < const Duration(seconds: 5)) || _speedWindow.isEmpty) return;
    _lastMlRequest = time;
    _lastMlPrediction = null;
    final speeds = _speedWindow.map((item) => item.speedKmh).toList();
    final mean = speeds.reduce((a, b) => a + b) / speeds.length;
    final variance = speeds.map((speed) => (speed - mean) * (speed - mean)).reduce((a, b) => a + b) / speeds.length;
    final window = MlFeatureWindow(avgSpeedKmh: mean, speedVarianceKmh2: variance, maxSpeedKmh: speeds.reduce((a, b) => a > b ? a : b), distanceM: _speedWindow.fold<double>(0, (sum, item) => sum + item.distanceM));
    _mlClassifier.classify(window).then((prediction) {
      _lastMlPrediction = switch (prediction) {
        'stationary' => DetectedTravelMode.stationary,
        'walking' => DetectedTravelMode.walking,
        'cycling' => DetectedTravelMode.cycling,
        'vehicle' => DetectedTravelMode.vehicle,
        _ => null,
      };
    });
  }

  void _begin(GpsSample sample, DetectedTravelMode mode) {
    _startedAt = sample.timestamp;
    _acceptedMode = mode;
    _modeDurations[mode] = Duration.zero;
    _tripGpsPoints.add({'latitude': sample.latitude, 'longitude': sample.longitude, 'speedMps': sample.speedMetresPerSecond, 'timestamp': sample.timestamp.toIso8601String()});
    _emitActive(sample.timestamp);
  }

  void _acceptModeAfterNoiseFilter(DetectedTravelMode mode, DateTime time, Duration elapsed) {
    if (mode == _acceptedMode) {
      _pendingMode = null;
      _modeDurations[mode] = (_modeDurations[mode] ?? Duration.zero) + elapsed;
    } else if (_pendingMode != mode) {
      _pendingMode = mode;
      _pendingSince = time;
    } else if (time.difference(_pendingSince!) >= modeChangeConfirmation) {
      _acceptedMode = mode;
      _pendingMode = null;
      _modeDurations[mode] = (_modeDurations[mode] ?? Duration.zero) + elapsed;
    }
  }

  void _emitActive(DateTime time) {
    final started = _startedAt;
    if (started != null && _acceptedMode != null) _activeTrips.add(DetectedTrip(id: '${started.microsecondsSinceEpoch}-active', distanceKm: _distanceMetres / 1000, mode: _dominantMode(), startedAt: started, endedAt: time, featureWindow: _featureWindow()));
  }

  void _complete(DateTime endedAt) {
    final started = _startedAt;
    if (started != null && _distanceMetres > 0) _completedTrips.add(DetectedTrip(id: '${started.microsecondsSinceEpoch}-${endedAt.microsecondsSinceEpoch}', distanceKm: _distanceMetres / 1000, mode: _dominantMode(), startedAt: started, endedAt: endedAt, featureWindow: _featureWindow()));
    _reset();
  }

  DetectedTravelMode _dominantMode() => _modeDurations.entries.fold<MapEntry<DetectedTravelMode, Duration>?>(null, (winner, entry) => winner == null || entry.value > winner.value ? entry : winner)?.key ?? _acceptedMode ?? DetectedTravelMode.walking;
  DetectedFeatureWindow _featureWindow() {
    final speeds = _tripSpeedObservations.map((point) => point.speedKmh).toList();
    final mean = speeds.isEmpty ? 0.0 : speeds.reduce((a, b) => a + b) / speeds.length;
    final variance = speeds.isEmpty ? 0.0 : speeds.map((speed) => (speed - mean) * (speed - mean)).reduce((a, b) => a + b) / speeds.length;
    return DetectedFeatureWindow(avgSpeedKmh: mean, speedVarianceKmh2: variance, maxSpeedKmh: speeds.isEmpty ? 0 : speeds.reduce((a, b) => a > b ? a : b), distanceM: _distanceMetres, gpsPoints: List.unmodifiable(_tripGpsPoints));
  }
  void _reset() {
    _previous = null; _startedAt = null; _stationarySince = null; _distanceMetres = 0;
    _modeDurations.clear(); _acceptedMode = null; _pendingMode = null; _pendingSince = null;
    _speedWindow.clear(); _lastMlRequest = null; _lastMlPrediction = null;
    _tripSpeedObservations.clear(); _tripGpsPoints.clear();
    _activeTrips.add(null);
  }
  static double _distanceBetween(GpsSample a, GpsSample b) {
    const radius = 6371000.0;
    final lat = _radians(b.latitude - a.latitude), lon = _radians(b.longitude - a.longitude);
    final h = math.sin(lat / 2) * math.sin(lat / 2) + math.cos(_radians(a.latitude)) * math.cos(_radians(b.latitude)) * math.sin(lon / 2) * math.sin(lon / 2);
    return 2 * radius * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }
  static double _radians(double degrees) => degrees * math.pi / 180;
}

class _SpeedObservation {
  const _SpeedObservation(this.timestamp, this.speedKmh, this.distanceM);
  final DateTime timestamp;
  final double speedKmh;
  final double distanceM;
}
