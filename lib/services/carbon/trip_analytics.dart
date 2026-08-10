import 'package:carbon_tracker/models/trip_model.dart';

enum ReportPeriod { week, month, allTime }

class TripAnalytics {
  const TripAnalytics._();

  static List<TripModel> forPeriod(List<TripModel> trips, ReportPeriod period, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return trips.where((trip) {
      return switch (period) {
        ReportPeriod.week => !trip.date.isBefore(today.subtract(const Duration(days: 6))),
        ReportPeriod.month => trip.date.year == today.year && trip.date.month == today.month,
        ReportPeriod.allTime => true,
      };
    }).toList();
  }

  static double totalCarbon(Iterable<TripModel> trips) =>
    trips.fold(0.0, (total, trip) => total + trip.carbonEmission);

static double totalDistance(Iterable<TripModel> trips) =>
    trips.fold(0.0, (total, trip) => total + trip.distance);

  static Map<TransportMode, double> emissionsByMode(Iterable<TripModel> trips) {
    final totals = {for (final mode in TransportMode.values) mode: 0.0};
    for (final trip in trips) {
      totals[trip.transportMode] = totals[trip.transportMode]! + trip.carbonEmission;
    }
    return totals;
  }

  static List<double> lastSevenDays(List<TripModel> trips, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (index) {
      final day = today.subtract(Duration(days: 6 - index));
      return totalCarbon(trips.where((trip) => _isSameDay(trip.date, day)));
    });
  }

  /// A transparent in-app habit score, not a scientific carbon target.
  static int ecoScore(List<TripModel> trips) {
    if (trips.isEmpty) return 0;
    final lowCarbonTrips = trips.where((trip) => trip.transportMode.emissionFactor <= 0.05).length;
    return ((lowCarbonTrips / trips.length) * 100).round();
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
