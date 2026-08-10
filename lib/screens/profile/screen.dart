import 'package:carbon_tracker/core/routes/app_routes.dart';
import 'package:carbon_tracker/core/theme/app_colors.dart';
import 'package:carbon_tracker/core/theme/spacing.dart';
import 'package:carbon_tracker/core/theme/text_styles.dart';
import 'package:carbon_tracker/models/trip_model.dart';
import 'package:carbon_tracker/repositories/trip_repository.dart';
import 'package:carbon_tracker/services/carbon/trip_analytics.dart';
import 'package:carbon_tracker/widgets/cards/app_card.dart';
import 'package:flutter/material.dart';
import 'package:carbon_tracker/services/auth/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text('My Profile', style: AppTextStyles.title), actions: [TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.settings), child: const Text('Edit'))]), body: SafeArea(top: false, child: ValueListenableBuilder<List<TripModel>>(valueListenable: TripRepository.instance.trips, builder: (context, trips, _) => SingleChildScrollView(padding: const EdgeInsets.all(AppSpacing.xl), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_header(), const SizedBox(height: AppSpacing.xl), _stats(trips), const SizedBox(height: AppSpacing.xxl), Text('Achievements', style: AppTextStyles.title), const SizedBox(height: AppSpacing.md), _achievements(trips), const SizedBox(height: AppSpacing.xxl), Text('Quick actions', style: AppTextStyles.title), const SizedBox(height: AppSpacing.md), InfoCard(child: Column(children: [_action(context, Icons.insights_outlined, 'Reports', AppRoutes.reports), _action(context, Icons.route_outlined, 'Trip History', AppRoutes.tripHistory), _action(context, Icons.settings_outlined, 'Settings', AppRoutes.settings)]))])))));
  Widget _header() => FutureBuilder<List<String?>>(future: Future.wait([AuthService.instance.currentUserName, AuthService.instance.currentUserEmail]), builder: (context,snapshot) { final user=snapshot.data; return InfoCard(child: Row(children: [const CircleAvatar(radius: 32, backgroundColor: Color(0xFFE0F7E9), child: Icon(Icons.person_rounded, size: 34, color: AppColors.darkGreen)), const SizedBox(width: AppSpacing.md), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user?[0] ?? 'Profile', style: AppTextStyles.title), Text(user?[1] ?? '', style: AppTextStyles.caption)])])); });
  Widget _stats(List<TripModel> trips) { final carbon = TripAnalytics.totalCarbon(trips); final distance = TripAnalytics.totalDistance(trips); return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [_stat('Trips', '${trips.length}'), _stat('CO₂', '${carbon.toStringAsFixed(1)} kg'), _stat('Distance', '${distance.toStringAsFixed(1)} km'), _stat('Eco score', '${TripAnalytics.ecoScore(trips)}%')]); }
  Widget _stat(String label, String value) => SizedBox(width: 150, child: InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: AppTextStyles.caption), Text(value, style: AppTextStyles.title)])));
  Widget _achievements(List<TripModel> trips) { final lowDay = trips.any((trip) => trip.carbonEmission <= .5); return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [_badge('First Trip', trips.isNotEmpty), _badge('5 Trips', trips.length >= 5), _badge('10 Trips', trips.length >= 10), _badge('Low Carbon Day', lowDay)]); }
  Widget _badge(String text, bool unlocked) => Chip(avatar: Icon(unlocked ? Icons.workspace_premium_rounded : Icons.lock_outline, color: unlocked ? AppColors.primary : AppColors.secondaryText), label: Text(text));
  Widget _action(BuildContext context, IconData icon, String label, String route) => ListTile(leading: Icon(icon, color: AppColors.darkGreen), title: Text(label), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pushNamed(context, route));
}
