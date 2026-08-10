enum TransportMode { walking, cycling, bike, car, bus, train, flight }

extension TransportModeDetails on TransportMode {
  String get label => switch (this) {
        TransportMode.walking => 'Walking',
        TransportMode.cycling => 'Cycling',
        TransportMode.bike => 'Bike',
        TransportMode.car => 'Car',
        TransportMode.bus => 'Bus',
        TransportMode.train => 'Train',
        TransportMode.flight => 'Flight',
      };

  double get emissionFactor => switch (this) {
        TransportMode.walking || TransportMode.cycling => 0,
        TransportMode.bike => 0.05,
        TransportMode.car => 0.21,
        TransportMode.bus => 0.10,
        TransportMode.train => 0.04,
        TransportMode.flight => 0.25,
      };
}

class TripModel {
  const TripModel({
    required this.id,
    required this.transportMode,
    required this.distance,
    required this.carbonEmission,
    required this.date,
    this.notes,
    this.serverId,
    this.synced = false,
  });

  final String id;
  final TransportMode transportMode;
  final double distance;
  final double carbonEmission;
  final DateTime date;
  final String? notes;
  final String? serverId;
  final bool synced;

  TransportMode get mode => transportMode;
  double get distanceKm => distance;
  double get carbonKg => carbonEmission;

  Map<String, dynamic> toJson() => {
        'id': id,
        'transportMode': transportMode.name,
        'distance': distance,
        'carbonEmission': carbonEmission,
        'date': date.toIso8601String(),
        'notes': notes,
        'serverId': serverId,
        'synced': synced,
      };

  factory TripModel.fromJson(Map<String, dynamic> json) {
    final modeName = json['transportMode'] ?? json['mode'];
    final rawId = json['id'] ?? json['_id'];
    return TripModel(
      id: rawId is String && rawId.isNotEmpty
          ? rawId
          : DateTime.now().microsecondsSinceEpoch.toString(),
      transportMode: TransportMode.values.firstWhere(
        (mode) => mode.name == modeName,
        orElse: () => TransportMode.car,
      ),
      distance: _asDouble(json['distance'] ?? json['distanceKm']),
      carbonEmission: _asDouble(json['carbonEmission'] ?? json['carbonKg']),
      date: _asDate(json['date']),
      notes: json['notes'] as String?,
      serverId: json['serverId'] as String? ?? json['_id'] as String?,
      synced: json['synced'] as bool? ?? json['_id'] != null,
    );
  }

  /// Safely converts backend numeric fields that may arrive as int,
  /// double, numeric String, or be missing/null entirely.
  static double _asDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Safely parses a date field, falling back to "now" instead of
  /// throwing when the backend sends a missing/malformed value.
  static DateTime _asDate(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
