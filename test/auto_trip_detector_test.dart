import 'package:carbon_tracker/services/gps/auto_trip_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifySpeedKmh', () {
    test('uses the Review-1 speed thresholds', () {
      expect(classifySpeedKmh(0), DetectedTravelMode.stationary);
      expect(classifySpeedKmh(1.99), DetectedTravelMode.stationary);
      expect(classifySpeedKmh(2), DetectedTravelMode.walking);
      expect(classifySpeedKmh(6.99), DetectedTravelMode.walking);
      expect(classifySpeedKmh(7), DetectedTravelMode.cycling);
      expect(classifySpeedKmh(20), DetectedTravelMode.cycling);
      expect(classifySpeedKmh(20.01), DetectedTravelMode.vehicle);
    });
  });
}
