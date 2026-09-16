import 'package:carbon_tracker/services/api/api_service.dart';
import 'package:carbon_tracker/services/auth/auth_service.dart';

/// Enable only in an explicitly configured build:
/// flutter run --dart-define=USE_ML_CLASSIFIER=true
const useMlClassifier = bool.fromEnvironment('USE_ML_CLASSIFIER', defaultValue: false);

class MlFeatureWindow {
  const MlFeatureWindow({required this.avgSpeedKmh, required this.speedVarianceKmh2, required this.maxSpeedKmh, required this.distanceM});
  final double avgSpeedKmh;
  final double speedVarianceKmh2;
  final double maxSpeedKmh;
  final double distanceM;

  Map<String, dynamic> toJson() => {
        'avg_speed_kmh': avgSpeedKmh,
        'speed_variance_kmh2': speedVarianceKmh2,
        'max_speed_kmh': maxSpeedKmh,
        'distance_m': distanceM,
        // GPS-only Flutter collection has no IMU stream yet. Explicit zeros make
        // this limitation observable in backend evaluation logs, not implicit.
        'accel_magnitude_mean': 0,
        'accel_magnitude_variance': 0,
        'accel_dominant_frequency_hz': 0,
      };
}

class MlTripClassifier {
  Future<String?> classify(MlFeatureWindow window) async {
    if (!useMlClassifier) return null;
    final token = await AuthService.instance.token;
    if (token == null) return null;
    try {
      final response = await ApiService.instance.classifyTrip(features: window.toJson(), token: token);
      final data = response['data'] as Map<String, dynamic>?;
      final label = data?['predicted_class'];
      return label is String && const {'stationary', 'walking', 'cycling', 'vehicle'}.contains(label) ? label : null;
    } catch (_) {
      // Automatic fallback is intentional; GPS trip detection must keep working
      // when the backend/model is offline, errors, or exceeds two seconds.
      return null;
    }
  }
}
