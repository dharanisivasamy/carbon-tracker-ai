import 'dart:async';

import 'package:carbon_tracker/core/theme/app_colors.dart';
import 'package:carbon_tracker/core/theme/spacing.dart';
import 'package:carbon_tracker/core/theme/text_styles.dart';
import 'package:carbon_tracker/models/trip_model.dart';
import 'package:carbon_tracker/repositories/trip_repository.dart';
import 'package:carbon_tracker/services/api/api_client.dart';
import 'package:carbon_tracker/services/api/api_service.dart';
import 'package:carbon_tracker/services/auth/auth_service.dart';
import 'package:carbon_tracker/services/location/trip_tracking_service.dart';
import 'package:carbon_tracker/services/gps/auto_trip_detector.dart';
import 'package:carbon_tracker/services/gps/gps_service.dart';
import 'package:carbon_tracker/screens/trips/add_trip_screen.dart';
import 'package:carbon_tracker/screens/trips/auto_detection_card.dart';
import 'package:carbon_tracker/repositories/labelled_window_repository.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carbon_tracker/utils/app_logger.dart';
import 'package:carbon_tracker/widgets/cards/app_card.dart';
import 'package:carbon_tracker/widgets/common/app_text_fields.dart';
import 'package:flutter/material.dart';

enum TripSort { newest, oldest, highestCarbon }

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  String _query = '';
  TransportMode? _filter;
  TripSort _sort = TripSort.newest;
  final _trackingService = TripTrackingService.instance;
  late final AutoTripDetector _autoDetector = AutoTripDetector(GpsService.instance);
  StreamSubscription<DetectedTrip>? _completedTripSubscription;
  DetectedTrip? _detectedTrip;
  bool _isSavingTrackedTrip = false;
  @override
  void initState() {
    super.initState();
    _completedTripSubscription = _autoDetector.completedTrips.listen((trip) {
      LabelledWindowRepository.instance.capture(trip);
      if (mounted) setState(() => _detectedTrip = trip);
    });
    _refresh();
  }

  Future<void> _refresh() async {
    final token = await AuthService.instance.token;
    if (token == null) return;
    try {
      // Upload any offline trips first so they show up as synced once we
      // pull the latest list from the server.
      await ApiService.instance.syncPendingTrips(token);
      final response = await ApiService.instance.trips(token);
      final data = response['data'] as List<dynamic>;
      await TripRepository.instance.replaceFromServer(
        data
            .map((item) => TripModel.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      // Server refresh failed (offline/server error) - local trips already
      // loaded and remain visible, which is the intended offline fallback.
      logDebug('[TRIPS] Failed to refresh from server: $e');
    }
  }

  @override
  void dispose() {
    // Trips are foreground-only; leaving this screen must not leave GPS on.
    _trackingService.stopTracking();
    _completedTripSubscription?.cancel();
    _autoDetector.stop();
    super.dispose();
  }

  Future<void> _enableAutoDetection() async {
    if (!await _showTrainingConsent()) return;
    final result = await _autoDetector.start();
    if (result == GpsStartResult.started || !mounted) return;
    final message = switch (result) {
      GpsStartResult.locationServicesDisabled => 'Turn on location services to detect trips.',
      GpsStartResult.permissionDenied => 'Location permission is needed to detect trips.',
      GpsStartResult.permissionDeniedForever => 'Location permission is permanently denied. Enable it in Settings.',
      GpsStartResult.started => '',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _showTrainingConsent() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('training_window_consent_v1') ?? false) return true;
    if (!mounted) return false;
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Trip-data training consent'), content: const Text('Confirmed trip GPS and speed feature windows will be stored on this device for model training. This does not store your name or account identity. You can export the labelled data manually later.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('I agree'))]));
    if (accepted == true) await prefs.setBool('training_window_consent_v1', true);
    return accepted == true;
  }

  TransportMode _modeForDetectedTrip(DetectedTravelMode mode) => switch (mode) {
        DetectedTravelMode.walking => TransportMode.walking,
        DetectedTravelMode.cycling => TransportMode.cycling,
        // Review 1 intentionally cannot split a vehicle into car/bus/train.
        DetectedTravelMode.vehicle => TransportMode.car,
        DetectedTravelMode.stationary => TransportMode.walking,
      };

  String _trainingLabel(TransportMode mode) => switch (mode) {
        TransportMode.walking => 'walking',
        TransportMode.cycling => 'cycling',
        _ => 'vehicle',
      };

  void _confirmDetectedTrip() {
    final trip = _detectedTrip;
    if (trip == null) return;
    setState(() => _detectedTrip = null);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddTripScreen(initialDistanceKm: trip.distanceKm, initialMode: _modeForDetectedTrip(trip.mode), autoSave: true, onSaved: (mode) => LabelledWindowRepository.instance.label(trip.id, _trainingLabel(mode))),
    ));
  }

  void _editDetectedTrip() {
    final trip = _detectedTrip;
    if (trip == null) return;
    setState(() => _detectedTrip = null);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddTripScreen(initialDistanceKm: trip.distanceKm, initialMode: _modeForDetectedTrip(trip.mode), onSaved: (mode) => LabelledWindowRepository.instance.label(trip.id, _trainingLabel(mode))),
    ));
  }

  Future<void> _startTrip() async {
    final started = await _trackingService.startTracking();
    if (!started && mounted) {
      final message =
          _trackingService.state.value.message ??
          'Could not start GPS tracking.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _stopTrip() async {
    final tracked = _trackingService.state.value;
    final distanceKm = await _trackingService.stopTracking();
    if (!mounted) return;
    if (distanceKm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No GPS distance was recorded, so no trip was saved.'),
        ),
      );
      return;
    }
    final details = await showDialog<_TrackedTripDetails>(
      context: context,
      builder: (_) => _SaveTrackedTripDialog(distanceKm: distanceKm),
    );
    if (details == null || _isSavingTrackedTrip) return;
    await _saveTrackedTrip(
      distanceKm,
      tracked.startedAt ?? DateTime.now(),
      details,
    );
  }

  Future<void> _saveTrackedTrip(
    double distanceKm,
    DateTime startedAt,
    _TrackedTripDetails details,
  ) async {
    if (_isSavingTrackedTrip) return;
    _isSavingTrackedTrip = true;
    try {
      final trip = TripModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        transportMode: details.mode,
        distance: distanceKm,
        carbonEmission: distanceKm * details.mode.emissionFactor,
        date: startedAt,
        notes: details.notes,
      );
      await TripRepository.instance.add(trip);
      final token = await AuthService.instance.token;
      if (token != null) await ApiService.instance.syncPendingTrips(token);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('GPS trip saved.')));
      }
    } finally {
      _isSavingTrackedTrip = false;
    }
  }

  /// Deletes a trip per its sync state:
  /// - Synced (has a serverId): delete on the backend first; only remove
  ///   the local record after the backend confirms deletion. If the
  ///   backend call fails, the local record is kept and an error shown.
  /// - Unsynced (local-only, never made it to the server): delete locally
  ///   only, no backend call is made.
  Future<void> _delete(TripModel trip) async {
    if (trip.synced && trip.serverId != null) {
      final token = await AuthService.instance.token;
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You need to be logged in to delete this trip.'),
            ),
          );
        }
        return;
      }
      try {
        await ApiService.instance.deleteTrip(trip.serverId!, token);
        await TripRepository.instance.delete(trip.id);
      } catch (e) {
        logDebug('[TRIPS] Backend delete failed for ${trip.serverId}: $e');
        if (mounted) {
          final message = e is ApiException
              ? e.message
              : 'Could not delete this trip. Please try again.';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    } else {
      await TripRepository.instance.delete(trip.id);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(title: Text('Trip History', style: AppTextStyles.title), actions: [IconButton(tooltip: 'Export labelled training windows', icon: const Icon(Icons.ios_share_rounded), onPressed: () async { await Clipboard.setData(ClipboardData(text: LabelledWindowRepository.instance.exportJson())); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Labelled training windows copied to clipboard.'))); })]),
    body: SafeArea(
      top: false,
      child: ValueListenableBuilder<List<TripModel>>(
        valueListenable: TripRepository.instance.trips,
        builder: (context, trips, _) {
          final visibleTrips = _visibleTrips(trips);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AutoDetectionCard(
                      isEnabled: _autoDetector.isListening,
                      trip: _detectedTrip,
                      onEnable: _enableAutoDetection,
                      onConfirm: _confirmDetectedTrip,
                      onEdit: _editDetectedTrip,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ValueListenableBuilder<TripTrackingState>(
                      valueListenable: _trackingService.state,
                      builder: (context, tracking, _) => _TrackingCard(
                        tracking: tracking,
                        onStart: _startTrip,
                        onStop: _stopTrip,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Search trips',
                      hint: 'Search by transport or notes',
                      prefixIcon: Icons.search_rounded,
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _FilterBar(
                      selected: _filter,
                      onSelected: (mode) => setState(() => _filter = mode),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: PopupMenuButton<TripSort>(
                        initialValue: _sort,
                        onSelected: (value) => setState(() => _sort = value),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: TripSort.newest,
                            child: Text('Newest'),
                          ),
                          PopupMenuItem(
                            value: TripSort.oldest,
                            child: Text('Oldest'),
                          ),
                          PopupMenuItem(
                            value: TripSort.highestCarbon,
                            child: Text('Highest CO₂'),
                          ),
                        ],
                        child: Chip(
                          avatar: const Icon(Icons.sort_rounded, size: 18),
                          label: Text(_sort.label),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (trips.isEmpty)
                      const _EmptyTrips()
                    else if (visibleTrips.isEmpty)
                      const _NoMatchingTrips()
                    else
                      ...visibleTrips.map(
                        (trip) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _TripCard(
                            trip: trip,
                            onDelete: () => _delete(trip),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  List<TripModel> _visibleTrips(List<TripModel> trips) {
    final query = _query.trim().toLowerCase();
    final result = trips.where((trip) {
      final matchesFilter = _filter == null || trip.mode == _filter;
      final matchesSearch =
          query.isEmpty ||
          trip.mode.label.toLowerCase().contains(query) ||
          (trip.notes?.toLowerCase().contains(query) ?? false);
      return matchesFilter && matchesSearch;
    }).toList();
    result.sort(
      (a, b) => switch (_sort) {
        TripSort.newest => b.date.compareTo(a.date),
        TripSort.oldest => a.date.compareTo(b.date),
        TripSort.highestCarbon => b.carbonKg.compareTo(a.carbonKg),
      },
    );
    return result;
  }
}

extension on TripSort {
  String get label => switch (this) {
    TripSort.newest => 'Newest',
    TripSort.oldest => 'Oldest',
    TripSort.highestCarbon => 'Highest CO₂',
  };
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final TransportMode? selected;
  final ValueChanged<TransportMode?> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        FilterChip(
          label: const Text('All'),
          selected: selected == null,
          onSelected: (_) => onSelected(null),
        ),
        ...TransportMode.values.map(
          (mode) => Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: FilterChip(
              label: Text(mode.label),
              selected: selected == mode,
              onSelected: (_) => onSelected(mode),
            ),
          ),
        ),
      ],
    ),
  );
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({
    required this.tracking,
    required this.onStart,
    required this.onStop,
  });

  final TripTrackingState tracking;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    if (!tracking.isTracking) {
      return FilledButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Start Trip'),
      );
    }
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gps_fixed_rounded, color: AppColors.darkGreen),
              const SizedBox(width: AppSpacing.xs),
              Text('Trip in progress', style: AppTextStyles.title),
              const Spacer(),
              const Chip(label: Text('GPS active')),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Current distance: ${tracking.distanceKm.toStringAsFixed(2)} km',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.xxs),
          _TrackingElapsedTime(startedAt: tracking.startedAt!),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Start time: ${_formatTime(tracking.startedAt!)}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStop,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Stop Trip'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingElapsedTime extends StatefulWidget {
  const _TrackingElapsedTime({required this.startedAt});

  final DateTime startedAt;

  @override
  State<_TrackingElapsedTime> createState() => _TrackingElapsedTimeState();
}

class _TrackingElapsedTimeState extends State<_TrackingElapsedTime> {
  late final Timer _timer = Timer.periodic(
    const Duration(seconds: 1),
    (_) => setState(() {}),
  );

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = DateTime.now().difference(widget.startedAt);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Text(
      'Tracking duration: $hours:$minutes:$seconds',
      style: AppTextStyles.caption,
    );
  }
}

class _TrackedTripDetails {
  const _TrackedTripDetails({required this.mode, this.notes});

  final TransportMode mode;
  final String? notes;
}

class _SaveTrackedTripDialog extends StatefulWidget {
  const _SaveTrackedTripDialog({required this.distanceKm});

  final double distanceKm;

  @override
  State<_SaveTrackedTripDialog> createState() => _SaveTrackedTripDialogState();
}

class _SaveTrackedTripDialogState extends State<_SaveTrackedTripDialog> {
  final _notesController = TextEditingController();
  TransportMode _mode = TransportMode.car;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Save tracked trip'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GPS distance: ${widget.distanceKm.toStringAsFixed(2)} km'),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<TransportMode>(
            value: _mode,
            decoration: const InputDecoration(labelText: 'Transport mode'),
            items: TransportMode.values
                .map(
                  (mode) =>
                      DropdownMenuItem(value: mode, child: Text(mode.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => _mode = value!),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            maxLines: 2,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _TrackedTripDetails(
            mode: _mode,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          ),
        ),
        child: const Text('Save Trip'),
      ),
    ],
  );
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onDelete});

  final TripModel trip;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => InfoCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: const BoxDecoration(
            color: Color(0xFFE0F7E9),
            shape: BoxShape.circle,
          ),
          child: Icon(_iconFor(trip.mode), color: AppColors.darkGreen),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trip.mode.label, style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${trip.distanceKm.toStringAsFixed(1)} km  •  ${trip.carbonKg.toStringAsFixed(2)} kg CO₂',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(_formatDate(trip.date), style: AppTextStyles.caption),
              if (trip.notes case final notes?) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(notes, style: AppTextStyles.body),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: 'Delete trip',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    ),
  );
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.huge),
    child: Column(
      children: [
        Icon(Icons.route_outlined, size: 56, color: AppColors.primary),
        SizedBox(height: AppSpacing.md),
        Text(
          'No trips yet',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          'Add your first trip to start tracking your carbon footprint.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _NoMatchingTrips extends StatelessWidget {
  const _NoMatchingTrips();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.huge),
    child: Column(
      children: [
        Icon(
          Icons.search_off_rounded,
          size: 48,
          color: AppColors.secondaryText,
        ),
        SizedBox(height: AppSpacing.sm),
        Text('No matching trips found'),
      ],
    ),
  );
}

IconData _iconFor(TransportMode mode) => switch (mode) {
  TransportMode.walking => Icons.directions_walk_rounded,
  TransportMode.cycling => Icons.directions_bike_rounded,
  TransportMode.bike => Icons.two_wheeler_rounded,
  TransportMode.car => Icons.directions_car_rounded,
  TransportMode.bus => Icons.directions_bus_rounded,
  TransportMode.train => Icons.train_rounded,
  TransportMode.flight => Icons.flight_rounded,
};

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _formatTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
