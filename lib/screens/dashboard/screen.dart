import 'package:carbon_tracker/core/routes/app_routes.dart';
import 'package:carbon_tracker/core/theme/app_colors.dart';
import 'package:carbon_tracker/core/theme/spacing.dart';
import 'package:carbon_tracker/core/theme/text_styles.dart';
import 'package:carbon_tracker/models/trip_model.dart';
import 'package:carbon_tracker/repositories/trip_repository.dart';
import 'package:carbon_tracker/screens/dashboard/widgets.dart';
import 'package:carbon_tracker/services/api/api_service.dart';
import 'package:carbon_tracker/services/auth/auth_service.dart';
import 'package:carbon_tracker/utils/app_logger.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override State<DashboardScreen> createState()=>_DashboardScreenState();
}
class _DashboardScreenState extends State<DashboardScreen> {
  Map<String,dynamic>? _serverSummary;
  @override void initState(){super.initState();_refresh();}
  Future<void> _refresh() async {
    final token = await AuthService.instance.token;
    if (token == null) return;
    try {
      await ApiService.instance.syncPendingTrips(token);
      final response = await ApiService.instance.summary(token);
      final data = response['data'];
      if (mounted) {
        setState(() => _serverSummary = data is Map<String, dynamic> ? data : null);
      }
    } catch (e) {
      // Local trip data (via ValueListenableBuilder below) already renders
      // immediately; a failed refresh just means we keep showing it.
      logDebug('[DASHBOARD] Failed to load server summary: $e');
    }
  }

  /// Safely parses recentTrips from the summary response. Any malformed
  /// entry falls back to the local trip list instead of crashing the UI.
  List<TripModel>? _serverRecentTrips() {
    final raw = _serverSummary?['recentTrips'];
    if (raw is! List) return null;
    try {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(TripModel.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  double? _num(dynamic value) => value is num ? value.toDouble() : null;
  int? _int(dynamic value) => value is num ? value.toInt() : null;

  /// Safely turns the summary's weeklyCarbon array into List<double>,
  /// tolerating null/non-numeric entries instead of throwing.
  List<double>? _serverWeeklyCarbon() {
    final raw = _serverSummary?['weeklyCarbon'];
    if (raw is! List) return null;
    return raw.map((value) => value is num ? value.toDouble() : 0.0).toList();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: Text('Dashboard', style: AppTextStyles.title)),
        body: SafeArea(
          top: false,
          child: ValueListenableBuilder<List<TripModel>>(
            valueListenable: TripRepository.instance.trips,
            builder: (context, trips, _) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.huge),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TodayCarbonCard(trips: trips, serverTotal: _num(_serverSummary?['todayCarbon'])),
                      const SizedBox(height: AppSpacing.md),
                      _StatsRow(
                        totalTrips: _int(_serverSummary?['totalTrips']) ?? trips.length,
                        totalDistance: _num(_serverSummary?['totalDistance']) ??
                            trips.fold<double>(0.0, (sum, trip) => sum + trip.distance),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text('Weekly Carbon', style: AppTextStyles.title),
                      const SizedBox(height: AppSpacing.md),
                      _WeeklyCarbonChart(trips: trips, serverValues: _serverWeeklyCarbon()),
                      const SizedBox(height: AppSpacing.xxl),
                      _SectionHeader(
                        title: 'Recent Trips',
                        actionLabel: 'View All',
                        onAction: () => Navigator.pushNamed(context, AppRoutes.tripHistory),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _RecentTripsCard(trips: _serverRecentTrips() ?? trips.take(3).toList()),
                      const SizedBox(height: AppSpacing.xxl),
                      _RecommendationCard(
                        onTap: () => Navigator.pushNamed(context, AppRoutes.recommendations),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Add trip',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.addTrip),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (index) {
            if (index == 1) Navigator.pushNamed(context, AppRoutes.tripHistory);
            if (index == 2) Navigator.pushNamed(context, AppRoutes.reports);
            if (index == 3) Navigator.pushNamed(context, AppRoutes.profile);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route_rounded), label: 'Trips'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      );
}

class _TodayCarbonCard extends StatelessWidget {
  const _TodayCarbonCard({required this.trips,this.serverTotal});
  final List<TripModel> trips;
  final double? serverTotal;

  @override
  Widget build(BuildContext context) {
    final todayTrips = trips.where((trip) => DateUtils.isSameDay(trip.date, DateTime.now())).toList();
    final double total = serverTotal ??
        todayTrips.fold<double>(
          0.0,
          (sum, trip) => sum + trip.carbonEmission,
        );
    return InfoCard(child: Row(children: [
      Container(padding: const EdgeInsets.all(AppSpacing.sm), decoration: const BoxDecoration(color: Color(0xFFE0F7E9), shape: BoxShape.circle), child: const Icon(Icons.co2_outlined, color: AppColors.darkGreen)),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Today's Carbon", style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.xxs),
        Text('${total.toStringAsFixed(2)} kg CO₂', style: AppTextStyles.title),
        Text('${todayTrips.length} trip${todayTrips.length == 1 ? '' : 's'} logged today', style: AppTextStyles.caption.copyWith(color: AppColors.darkGreen)),
      ])),
    ]));
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.totalTrips, required this.totalDistance});
  final int totalTrips;
  final double totalDistance;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: InfoCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total Trips', style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.xxs),
              Text('$totalTrips', style: AppTextStyles.title),
            ]),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: InfoCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total Distance', style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.xxs),
              Text('${totalDistance.toStringAsFixed(1)} km', style: AppTextStyles.title),
            ]),
          ),
        ),
      ]);
}

class _WeeklyCarbonChart extends StatelessWidget {
  const _WeeklyCarbonChart({required this.trips,this.serverValues});

  final List<TripModel> trips;
  final List<double>? serverValues;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());

    final days = List.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );

    final totals = serverValues ?? days
        .map(
          (day) => trips
              .where((trip) => DateUtils.isSameDay(trip.date, day))
              .fold(0.0, (sum, trip) => sum + trip.carbonEmission),
        )
        .toList();

    final maximum =
        totals.fold(0.0, (max, value) => value > max ? value : max);

    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return InfoCard(
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(
            7,
            (index) => Expanded(
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
                          heightFactor:
                              maximum == 0 ? 0 : totals[index] / maximum,
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
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      labels[days[index].weekday - 1],
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.actionLabel, required this.onAction});
  final String title; final String actionLabel; final VoidCallback onAction;
  @override Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: AppTextStyles.title), TextButton(onPressed: onAction, child: Text(actionLabel))]);
}

class _RecentTripsCard extends StatelessWidget {
  const _RecentTripsCard({required this.trips});
  final List<TripModel> trips;
  @override Widget build(BuildContext context) => InfoCard(child: trips.isEmpty ? const Text('No trips yet. Add a trip to start tracking.', textAlign: TextAlign.center) : Column(children: [for (var index = 0; index < trips.length; index++) ...[_TripRow(trip: trips[index]), if (index < trips.length - 1) const Divider(height: AppSpacing.xl * 2)]]));
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.trip}); final TripModel trip;
  @override Widget build(BuildContext context) => Row(children: [
    Container(padding: const EdgeInsets.all(AppSpacing.xs), decoration: const BoxDecoration(color: Color(0xFFE0F7E9), shape: BoxShape.circle), child: Icon(_iconFor(trip.transportMode), color: AppColors.darkGreen)),
    const SizedBox(width: AppSpacing.sm), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(trip.transportMode.label, style: AppTextStyles.body.copyWith(color: AppColors.primaryText)), Text('${trip.distance.toStringAsFixed(1)} km', style: AppTextStyles.caption)])),
    Text('${trip.carbonEmission.toStringAsFixed(2)} kg CO₂', style: AppTextStyles.caption.copyWith(color: AppColors.primaryText)),
  ]);
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.onTap});
  final VoidCallback onTap;
  @override Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: InfoCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.tips_and_updates_outlined, color: AppColors.darkGreen), const SizedBox(width: AppSpacing.sm), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Tip', style: AppTextStyles.title), const SizedBox(height: AppSpacing.xs), Text('Try combining errands into one trip this week to reduce your emissions.', style: AppTextStyles.body), const SizedBox(height: AppSpacing.xs), Text('See all recommendations →', style: AppTextStyles.caption.copyWith(color: AppColors.darkGreen))]))])),
  );
}

IconData _iconFor(TransportMode mode) => switch (mode) {
  TransportMode.walking => Icons.directions_walk_rounded, TransportMode.cycling => Icons.directions_bike_rounded,
  TransportMode.bike => Icons.two_wheeler_rounded, TransportMode.car => Icons.directions_car_rounded,
  TransportMode.bus => Icons.directions_bus_rounded, TransportMode.train => Icons.train_rounded, TransportMode.flight => Icons.flight_rounded,
};
