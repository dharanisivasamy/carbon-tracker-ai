import 'api_client.dart';
import 'api_endpoints.dart';
import 'package:carbon_tracker/models/trip_model.dart';
import 'package:carbon_tracker/repositories/trip_repository.dart';
import 'package:carbon_tracker/utils/app_logger.dart';

class ApiService {
  ApiService._();
  static final instance = ApiService._();
  final _client = ApiClient();

  Future<Map<String, dynamic>> login(String email, String password) =>
      _client.request('POST', ApiEndpoints.login, body: {'email': email, 'password': password});

  Future<Map<String, dynamic>> register(String name, String email, String password) =>
      _client.request('POST', ApiEndpoints.register, body: {'name': name, 'email': email, 'password': password});

  Future<Map<String, dynamic>> createTrip({
    required String mode,
    required double distance,
    required DateTime date,
    String? notes,
    required String token,
  }) =>
      _client.request(
        'POST',
        ApiEndpoints.trips,
        token: token,
        body: {
          'transportMode': mode,
          'distance': distance,
          'date': date.toIso8601String().split('T').first,
          'notes': notes,
        },
      );

  Future<Map<String, dynamic>> trips(String token) => _client.request('GET', ApiEndpoints.trips, token: token);

  Future<Map<String, dynamic>> trip(String id, String token) =>
      _client.request('GET', '${ApiEndpoints.trips}/$id', token: token);

  Future<Map<String, dynamic>> deleteTrip(String id, String token) =>
      _client.request('DELETE', '${ApiEndpoints.trips}/$id', token: token);

  Future<Map<String, dynamic>> summary(String token) => _client.request('GET', ApiEndpoints.tripSummary, token: token);

  Future<Map<String, dynamic>> reports(String period, String token) =>
      _client.request('GET', '${ApiEndpoints.tripReports}?period=$period', token: token);

  Future<Map<String, dynamic>> recommendations(String token) =>
      _client.request('GET', ApiEndpoints.tripRecommendations, token: token);

  /// Confirms the token is still accepted by the backend. Used to validate
  /// a stored session on app start instead of trusting local storage alone.
  Future<Map<String, dynamic>> me(String token) =>
      _client.request('GET', ApiEndpoints.me, token: token);

  /// Uploads any locally saved trips that have not yet been synced to the
  /// backend. Each trip is uploaded at most once per call and is only
  /// marked synced after the server confirms creation, so a failed upload
  /// is safely retried on the next call without creating duplicates.
  Future<void> syncPendingTrips(String token) async {
    for (final trip in TripRepository.instance.pendingTrips) {
      try {
        final response = await createTrip(
          mode: trip.transportMode.name,
          distance: trip.distance,
          date: trip.date,
          notes: trip.notes,
          token: token,
        );
        final id = (response['data'] as Map<String, dynamic>?)?['_id'] as String?;
        if (id != null) {
          await TripRepository.instance.markSynced(trip.id, id);
        }
      } catch (e) {
        // Keep the trip local/unsynced so it is retried on the next sync
        // pass instead of being lost.
        logDebug('[SYNC] Failed to sync trip ${trip.id}: $e');
      }
    }
  }
}
