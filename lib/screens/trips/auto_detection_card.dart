import 'package:carbon_tracker/core/theme/spacing.dart';
import 'package:carbon_tracker/services/gps/auto_trip_detector.dart';
import 'package:carbon_tracker/widgets/cards/app_card.dart';
import 'package:flutter/material.dart';

class AutoDetectionCard extends StatelessWidget {
  const AutoDetectionCard({required this.isEnabled, required this.trip, required this.onEnable, required this.onConfirm, required this.onEdit});
  final bool isEnabled;
  final DetectedTrip? trip;
  final VoidCallback onEnable, onConfirm, onEdit;
  @override
  Widget build(BuildContext context) {
    final completed = trip;
    if (completed == null) return FilledButton.icon(
      onPressed: isEnabled ? null : onEnable,
      icon: const Icon(Icons.auto_awesome_rounded),
      label: Text(isEnabled ? 'Auto trip detection is on' : 'Enable auto trip detection'),
    );
    final label = switch (completed.mode) {
      DetectedTravelMode.walking => 'Walking', DetectedTravelMode.cycling => 'Cycling',
      DetectedTravelMode.vehicle => 'Vehicle', DetectedTravelMode.stationary => 'Stationary',
    };
    return InfoCard(child: Row(children: [
      const Icon(Icons.location_on_rounded), const SizedBox(width: AppSpacing.sm),
      Expanded(child: Text('$label trip, ${completed.distanceKm.toStringAsFixed(1)} km — confirm?')),
      IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_rounded), onPressed: onEdit),
      IconButton(tooltip: 'Confirm trip', icon: const Icon(Icons.check_rounded), onPressed: onConfirm),
    ]));
  }
}
