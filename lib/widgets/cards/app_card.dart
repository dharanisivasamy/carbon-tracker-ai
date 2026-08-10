import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class CarbonCard extends StatelessWidget {
  const CarbonCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.primary,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class StatCard extends InfoCard {
  const StatCard({super.key, required super.child});
}
