import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum TripTrackingStatus { idle, tracking, locationServicesDisabled, permissionDenied, permissionDeniedForever, error }

class TripTrackingState {
  const TripTrackingState({
    required this.status,
    this.distanceMeters = 0,
    this.startedAt,
    this.message,
  });

  final TripTrackingStatus status;
  final double distanceMeters;
  final DateTime? startedAt;
  final String? message;

  bool get isTracking => status == TripTrackingStatus.tracking;
  double get distanceKm => distanceMeters / 1000;
}

/// Foreground-only GPS trip tracker. It deliberately owns the position
/// subscription so the UI never has to manage stream lifecycle details.
class TripTrackingService {
  TripTrackingService._();

  static final instance = TripTrackingService._();

  final ValueNotifier<TripTrackingState> state =
      ValueNotifier(const TripTrackingState(status: TripTrackingStatus.idle));
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;

  Future<bool> startTracking() async {
    if (state.value.isTracking) return true;

    if (!await Geolocator.isLocationServiceEnabled()) {
      _setStatus(TripTrackingStatus.locationServicesDisabled,
          'Location services are disabled. Turn them on and try again.');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _setStatus(TripTrackingStatus.permissionDeniedForever,
          'Location permission is permanently denied. Enable it in Settings.');
      return false;
    }
    if (permission == LocationPermission.denied) {
      _setStatus(TripTrackingStatus.permissionDenied,
          'Location permission is needed to track a trip.');
      return false;
    }

    _lastPosition = null;
    state.value = TripTrackingState(
      status: TripTrackingStatus.tracking,
      startedAt: DateTime.now(),
    );
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
    _positionSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (Object error) {
        _setStatus(TripTrackingStatus.error, 'GPS tracking failed: $error');
        unawaited(_cancelSubscription());
      },
    );
    return true;
  }

  void _onPosition(Position position) {
    final previous = _lastPosition;
    _lastPosition = position;
    if (previous == null || !state.value.isTracking) return;

    final meters = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      position.latitude,
      position.longitude,
    );
    final elapsedSeconds = position.timestamp.difference(previous.timestamp).inSeconds;
    // Reject normal GPS jitter, huge one-sample jumps, and implausibly fast
    // movement. This is deliberately generous enough for the listed modes.
    final speedMetresPerSecond = elapsedSeconds > 0 ? meters / elapsedSeconds : 0;
    if (meters < 3 || meters > 2000 || speedMetresPerSecond > 100) return;

    state.value = TripTrackingState(
      status: TripTrackingStatus.tracking,
      distanceMeters: state.value.distanceMeters + meters,
      startedAt: state.value.startedAt,
    );
  }

  /// Returns the final distance and resets this service to its idle state.
  Future<double> stopTracking() async {
    final distanceKm = state.value.distanceKm;
    await _cancelSubscription();
    _lastPosition = null;
    state.value = const TripTrackingState(status: TripTrackingStatus.idle);
    return distanceKm;
  }

  Future<void> dispose() async {
    await _cancelSubscription();
    _lastPosition = null;
    state.value = const TripTrackingState(status: TripTrackingStatus.idle);
    state.dispose();
  }

  Future<void> _cancelSubscription() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void _setStatus(TripTrackingStatus status, String message) {
    state.value = TripTrackingState(status: status, message: message);
  }
}
