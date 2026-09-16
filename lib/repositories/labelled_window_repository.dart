import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carbon_tracker/services/gps/auto_trip_detector.dart';

class LabelledWindowRepository {
  LabelledWindowRepository._();
  static final instance = LabelledWindowRepository._();
  static const _key = 'labelled_feature_windows_v1';
  final windows = ValueNotifier<List<Map<String, dynamic>>>(const []);
  SharedPreferences? _prefs;
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    windows.value = (_prefs!.getStringList(_key) ?? const []).map((item) => jsonDecode(item) as Map<String, dynamic>).toList(growable: false);
  }
  Future<void> capture(DetectedTrip trip) async {
    if (windows.value.any((window) => window['id'] == trip.id)) return;
    windows.value = [...windows.value, {'id': trip.id, 'capturedAt': trip.endedAt.toIso8601String(), 'label': null, 'synced': false, 'features': trip.featureWindow.toJson()}];
    await _persist();
  }
  Future<void> label(String id, String label) async {
    windows.value = windows.value.map((window) => window['id'] == id ? {...window, 'label': label, 'labelledAt': DateTime.now().toIso8601String(), 'synced': false} : window).toList(growable: false);
    await _persist();
  }
  String exportJson() => const JsonEncoder.withIndent('  ').convert(windows.value.where((window) => window['label'] != null).toList());
  Future<void> clear() async { windows.value = const []; await _persist(); }
  Future<void> _persist() async { _prefs ??= await SharedPreferences.getInstance(); await _prefs!.setStringList(_key, windows.value.map(jsonEncode).toList()); }
}
