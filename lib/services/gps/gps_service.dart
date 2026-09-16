import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// A UI-independent GPS reading. Speeds are supplied in metres per second.
class GpsSample {
  const GpsSample({required this.latitude, required this.longitude, required this.speedMetresPerSecond, required this.timestamp});
  final double latitude;
  final double longitude;
  final double speedMetresPerSecond;
  final DateTime timestamp;
  double get speedKilometresPerHour => speedMetresPerSecond * 3.6;
}

enum GpsStartResult { started, locationServicesDisabled, permissionDenied, permissionDeniedForever }

/// Foreground GPS source. Consumers subscribe to [samples], without needing
/// to handle platform permission state or Geolocator Position objects.
class GpsService {
  GpsService._();
  static final instance = GpsService._();

  final _samples = StreamController<GpsSample>.broadcast();
  StreamSubscription<Position>? _positionSubscription;
  Stream<GpsSample> get samples => _samples.stream;
  bool get isRunning => _positionSubscription != null;

  Future<GpsStartResult> start() async {
    if (isRunning) return GpsStartResult.started;
    if (!await Geolocator.isLocationServiceEnabled()) return GpsStartResult.locationServicesDisabled;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) return GpsStartResult.permissionDeniedForever;
    if (permission == LocationPermission.denied) return GpsStartResult.permissionDenied;
    const settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);
    _positionSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) => _samples.add(GpsSample(
        latitude: position.latitude,
        longitude: position.longitude,
        speedMetresPerSecond: position.speed < 0 ? 0 : position.speed,
        timestamp: position.timestamp,
      )),
      onError: _samples.addError,
    );
    return GpsStartResult.started;
  }

  Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
