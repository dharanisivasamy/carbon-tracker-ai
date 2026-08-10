import 'package:flutter/material.dart';
import 'package:carbon_tracker/core/theme/app_colors.dart';
import 'package:carbon_tracker/core/theme/spacing.dart';

class InfoCard extends StatelessWidget {
  final Widget child;

  const InfoCard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );
  }
}

class CarbonCard extends StatelessWidget {
  final Widget child;

  const CarbonCard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            AppColors.darkGreen,
            AppColors.primary,
          ],
        ),
      ),
      child: child,
    );
  }
}