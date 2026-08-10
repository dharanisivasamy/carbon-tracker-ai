import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService._();

  static final instance = LocationService._();

  StreamSubscription<Position>? _positionSubscription;

  Position? _lastPosition;
  double _totalDistanceMeters = 0;

  bool get isTracking => _positionSubscription != null;

  double get totalDistanceKm => _totalDistanceMeters / 1000;

  Future<bool> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<bool> startTracking() async {
    if (isTracking) return true;

    final allowed = await _checkPermission();

    if (!allowed) {
      return false;
    }

    _totalDistanceMeters = 0;
    _lastPosition = null;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (Position position) {
        if (_lastPosition != null) {
          final distance = Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );

          // Ignore tiny GPS inaccuracies.
          if (distance >= 3) {
            _totalDistanceMeters += distance;
          }
        }

        _lastPosition = position;
      },
    );

    return true;
  }

  Future<double> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    final distance = totalDistanceKm;

    _lastPosition = null;
    _totalDistanceMeters = 0;

    return distance;
  }

  Future<void> dispose() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}