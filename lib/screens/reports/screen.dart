import 'package:flutter/material.dart';

import 'package:carbon_tracker/core/routes/app_routes.dart';
import 'package:carbon_tracker/core/theme/app_colors.dart';
import 'package:carbon_tracker/core/theme/spacing.dart';
import 'package:carbon_tracker/core/theme/text_styles.dart';
import 'package:carbon_tracker/models/trip_model.dart';
import 'package:carbon_tracker/repositories/trip_repository.dart';
import 'package:carbon_tracker/services/api/api_service.dart';
import 'package:carbon_tracker/services/auth/auth_service.dart';
import 'package:carbon_tracker/services/carbon/trip_analytics.dart';
import 'package:carbon_tracker/utils/app_logger.dart';
import 'package:carbon_tracker/widgets/buttons/app_button.dart';
import 'package:carbon_tracker/widgets/cards/app_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.week;

  /// Raw `data` object from GET /trips/reports for the current period, or
  /// null if it hasn't loaded / the request failed / the user is offline.
  /// The UI always has local values to fall back on, so a null here just
  /// means "show local".
  Map<String, dynamic>? _serverReport;
  bool _loadingServer = false;

  @override
  void initState() {
    super.initState();
    _loadServerReport();
  }

  Future<void> _loadServerReport() async {
    final token = await AuthService.instance.token;
    if (token == null) {
      if (mounted) setState(() => _serverReport = null);
      return;
    }
    if (mounted) setState(() => _loadingServer = true);
    try {
      final response = await ApiService.instance.reports(_period.name, token);
      final data = response['data'] as Map<String, dynamic>?;
      if (mounted) setState(() => _serverReport = data);
    } catch (e) {
      // Keep whatever local data is already showing; just log for
      // diagnostics instead of surfacing a popup for a background refresh.
      logDebug('[REPORTS] Failed to load server report: $e');
    } finally {
      if (mounted) setState(() => _loadingServer = false);
    }
  }

  void _onPeriodChanged(ReportPeriod period) {
    setState(() {
      _period = period;
      // Clear the stale server snapshot for the old period immediately so
      // we never show last period's server numbers under a new label.
      _serverReport = null;
    });
    _loadServerReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Carbon Reports',
          style: AppTextStyles.title,
        ),
        actions: [
          if (_loadingServer)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder<List<TripModel>>(
          valueListenable: TripRepository.instance.trips,
          builder: (context, trips, _) {
            // Local trips are empty and we don't have a server report yet:
            // while a fetch is still in flight this is "loading", not
            // "empty" - the server may still have data for this account
            // even though nothing has synced to local storage yet.
            final hasServerReport = _serverReport != null;
            if (trips.isEmpty && !hasServerReport) {
              if (_loadingServer) {
                return const Center(child: CircularProgressIndicator());
              }
              return const _ReportsEmptyState();
            }

            final periodTrips = TripAnalytics.forPeriod(
              trips,
              _period,
              DateTime.now(),
            );

            final serverTransportBreakdown = _parseTransportBreakdown(
              _serverReport?['transportBreakdown'],
            );
            final serverWeeklyCarbon = _parseDoubleList(
              _serverReport?['weeklyCarbon'],
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 680,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Understand your carbon footprint',
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      SegmentedButton<ReportPeriod>(
                        segments: const [
                          ButtonSegment(
                            value: ReportPeriod.week,
                            label: Text('This Week'),
                          ),
                          ButtonSegment(
                            value: ReportPeriod.month,
                            label: Text('This Month'),
                          ),
                          ButtonSegment(
                            value: ReportPeriod.allTime,
                            label: Text('All Time'),
                          ),
                        ],
                        selected: {_period},
                        onSelectionChanged: (selection) => _onPeriodChanged(selection.first),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      _Summary(
                        trips: periodTrips,
                        serverTotalCarbon: _asDouble(_serverReport?['totalCarbon']),
                        serverTotalTrips: _asInt(_serverReport?['totalTrips']),
                        serverAverageCarbon: _asDouble(_serverReport?['averageCarbon']),
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      Text(
                        'Last 7 days',
                        style: AppTextStyles.title,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      _SevenDayChart(
                        trips: trips,
                        serverValues: serverWeeklyCarbon,
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      Text(
                        'Transport breakdown',
                        style: AppTextStyles.title,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      _TransportBreakdown(
                        trips: periodTrips,
                        serverBreakdown: serverTransportBreakdown,
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      _EcoProgressCard(
                        trips: periodTrips,
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
  }

  double? _asDouble(dynamic value) => value is num ? value.toDouble() : null;
  int? _asInt(dynamic value) => value is num ? value.toInt() : null;

  /// Safely turns the backend's `weeklyCarbon` array into a `List<double>`,
  /// or null if it's missing/malformed so callers fall back to local data.
  List<double>? _parseDoubleList(dynamic value) {
    if (value is! List) return null;
    try {
      return value.map((item) => (item as num).toDouble()).toList();
    } catch (_) {
      return null;
    }
  }

  /// Safely turns the backend's `transportBreakdown` object into a
  /// `Map<TransportMode, double>`, ignoring unknown keys/values so a
  /// partial or extended response never crashes the UI.
  Map<TransportMode, double>? _parseTransportBreakdown(dynamic value) {
    if (value is! Map) return null;
    final result = <TransportMode, double>{};
    for (final mode in TransportMode.values) {
      final raw = value[mode.name];
      if (raw is num) result[mode] = raw.toDouble();
    }
    return result.isEmpty ? null : result;
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.trips,
    this.serverTotalCarbon,
    this.serverTotalTrips,
    this.serverAverageCarbon,
  });

  final List<TripModel> trips;
  final double? serverTotalCarbon;
  final int? serverTotalTrips;
  final double? serverAverageCarbon;

  @override
  Widget build(BuildContext context) {
    final localTotal = TripAnalytics.totalCarbon(trips);
    final total = serverTotalCarbon ?? localTotal;
    final tripCount = serverTotalTrips ?? trips.length;
    final average = serverAverageCarbon ?? (trips.isEmpty ? 0.0 : localTotal / trips.length);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _Stat(
          label: 'Total CO₂',
          value: '${total.toStringAsFixed(2)} kg',
        ),
        _Stat(
          label: 'Trips',
          value: '$tripCount',
        ),
        _Stat(
          label: 'Average / trip',
          value: '${average.toStringAsFixed(2)} kg',
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: AppTextStyles.title,
            ),
          ],
        ),
      ),
    );
  }
}

class _SevenDayChart extends StatelessWidget {
  const _SevenDayChart({
    required this.trips,
    this.serverValues,
  });

  final List<TripModel> trips;
  final List<double>? serverValues;

  @override
  Widget build(BuildContext context) {
    final localValues = TripAnalytics.lastSevenDays(
      trips,
      DateTime.now(),
    );

    // Only trust the server values if they're actually a 7-day series;
    // otherwise silently fall back to the local computation.
    final values = (serverValues != null && serverValues!.length == 7) ? serverValues! : localValues;

    final highest = values.fold<double>(
      0.0,
      (max, value) => value > max ? value : max,
    );

    final now = DateTime.now();

    const labels = [
      'M',
      'T',
      'W',
      'T',
      'F',
      'S',
      'S',
    ];

    return InfoCard(
      child: SizedBox(
        height: 160,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(
            7,
            (index) {
              final day = now.subtract(
                Duration(days: 6 - index),
              );

              final heightFactor = highest == 0
                  ? 0.0
                  : values[index] / highest;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: heightFactor,
                            child: Container(
                              decoration: BoxDecoration(
                                color: index == 6
                                    ? AppColors.primary
                                    : const Color(0xFFC9F2D7),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: AppSpacing.xs,
                      ),
                      Text(
                        labels[day.weekday - 1],
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TransportBreakdown extends StatelessWidget {
  const _TransportBreakdown({
    required this.trips,
    this.serverBreakdown,
  });

  final List<TripModel> trips;
  final Map<TransportMode, double>? serverBreakdown;

  @override
  Widget build(BuildContext context) {
    final localModes = TripAnalytics.emissionsByMode(trips);
    final modes = serverBreakdown ?? localModes;
    final total = modes.values.fold(0.0, (sum, value) => sum + value);

    return InfoCard(
      child: Column(
        children: [
          for (final mode in TransportMode.values) ...[
            _ModeRow(
              mode: mode,
              total: modes[mode] ?? 0,
              percentage: total == 0
                  ? 0
                  : (modes[mode] ?? 0) / total,
            ),
            if (mode != TransportMode.values.last)
              const Divider(),
          ],
        ],
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.mode,
    required this.total,
    required this.percentage,
  });

  final TransportMode mode;
  final double total;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        _modeIcon(mode),
        color: AppColors.darkGreen,
      ),
      title: Text(mode.label),
      subtitle: Text(
        '${(percentage * 100).round()}% of emissions',
      ),
      trailing: Text(
        '${total.toStringAsFixed(2)} kg CO₂',
        style: AppTextStyles.caption,
      ),
    );
  }
}

class _EcoProgressCard extends StatelessWidget {
  const _EcoProgressCard({
    required this.trips,
  });

  final List<TripModel> trips;

  @override
  Widget build(BuildContext context) {
    final score = TripAnalytics.ecoScore(trips);

    return CarbonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Eco progress',
            style: AppTextStyles.title.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(
            height: AppSpacing.xs,
          ),
          Text(
            '$score% low-carbon trips',
            style: AppTextStyles.headline.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(
            height: AppSpacing.xs,
          ),
          const Text(
            'This is an in-app habit metric, not a scientifically validated carbon target.',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsEmptyState extends StatelessWidget {
  const _ReportsEmptyState();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.insights_outlined,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(
                height: AppSpacing.lg,
              ),
              Text(
                'No trip data yet',
                style: AppTextStyles.title,
              ),
              const SizedBox(
                height: AppSpacing.xs,
              ),
              Text(
                'Add your first trip to see your carbon reports.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(
                height: AppSpacing.xl,
              ),
              PrimaryButton(
                label: 'Add Trip',
                icon: Icons.add,
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.addTrip,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _modeIcon(TransportMode mode) {
  return switch (mode) {
    TransportMode.walking => Icons.directions_walk_rounded,
    TransportMode.cycling => Icons.directions_bike_rounded,
    TransportMode.bike => Icons.two_wheeler_rounded,
    TransportMode.car => Icons.directions_car_rounded,
    TransportMode.bus => Icons.directions_bus_rounded,
    TransportMode.train => Icons.train_rounded,
    TransportMode.flight => Icons.flight_rounded,
  };
}