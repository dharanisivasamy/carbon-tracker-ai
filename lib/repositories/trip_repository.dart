import 'dart:convert';

import 'package:carbon_tracker/models/trip_model.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent local trip store backed by SharedPreferences.
class TripRepository {
  TripRepository._();

  static final TripRepository instance = TripRepository._();

  static const _storageKey = 'trips_v1';
  final ValueNotifier<List<TripModel>> _trips = ValueNotifier(const []);
  SharedPreferences? _preferences;

  ValueListenable<List<TripModel>> get trips => _trips;

  Future<void> initialize() async {
    _preferences ??= await SharedPreferences.getInstance();
    final savedTrips = _preferences!.getStringList(_storageKey) ?? const [];
    final trips = <TripModel>[];
    for (final savedTrip in savedTrips) {
      try {
        trips.add(TripModel.fromJson(jsonDecode(savedTrip) as Map<String, dynamic>));
      } on FormatException {
        // Ignore an invalid record while retaining the rest of local history.
      }
    }
    trips.sort((a, b) => b.date.compareTo(a.date));
    _trips.value = List.unmodifiable(trips);
  }

  Future<void> add(TripModel trip) async {
    _trips.value = [trip, ..._trips.value];
    await _persist();
  }

  Future<void> delete(String id) async {
    _trips.value = _trips.value.where((trip) => trip.id != id).toList(growable: false);
    await _persist();
  }
  Future<void> clear() async { _trips.value = const []; await _persist(); }

  Future<void> replaceFromServer(List<TripModel> serverTrips) async {
    final locals = _trips.value.where((trip) => !trip.synced).toList();
    _trips.value = [...serverTrips, ...locals]..sort((a, b) => b.date.compareTo(a.date));
    await _persist();
  }

  List<TripModel> get pendingTrips => _trips.value
      .where((trip) => !trip.synced && trip.serverId == null)
      .toList(growable: false);

  Future<void> markSynced(String localId, String serverId) async {
    _trips.value = _trips.value.map((trip) => trip.id == localId
        ? TripModel(id: trip.id, transportMode: trip.transportMode, distance: trip.distance, carbonEmission: trip.carbonEmission, date: trip.date, notes: trip.notes, serverId: serverId, synced: true)
        : trip).toList(growable: false);
    await _persist();
  }

  Future<void> _persist() async {
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setStringList(
      _storageKey,
      _trips.value.map((trip) => jsonEncode(trip.toJson())).toList(growable: false),
    );
  }
}
