import 'dart:async';

import 'package:carbon_tracker/core/routes/app_routes.dart';
import 'package:carbon_tracker/core/theme/app_colors.dart';
import 'package:carbon_tracker/core/theme/text_styles.dart';
import 'package:carbon_tracker/services/auth/auth_service.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // Start the auth check immediately, but always show the splash for a
    // minimum amount of time so it doesn't just flash on screen.
    final storedTokenFuture = AuthService.instance.token;
    await Future<void>.delayed(const Duration(seconds: 2));
    final storedToken = await storedTokenFuture;
    if (!mounted) return;

    if (storedToken == null) {
      // Never seen a login - straight to onboarding, not dashboard.
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      return;
    }

    // A token exists locally, but that alone doesn't mean it's still
    // valid - confirm with the backend before trusting it for navigation.
    final isValid = await AuthService.instance.validateSession();
    if (!mounted) return;

    if (isValid) {
      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      return;
    }

    // Session invalid: the 401 from validateSession's backend check
    // already triggered ApiClient.onSessionExpired (see main.dart), which
    // clears auth and redirects to Login with a readable message. Give it
    // a brief moment to complete so we don't race it with a duplicate,
    // message-less navigation; fall back to a plain redirect ourselves
    // only if it hasn't happened yet, so we never get stuck on splash.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.darkGreen, AppColors.primary, AppColors.success],
        ),
      ),
      child: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _animation, curve: Curves.easeOut),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.surface,
                child: Icon(
                  Icons.eco_rounded,
                  size: 50,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Carbonly',
                style: AppTextStyles.display.copyWith(color: AppColors.surface),
              ),
              const SizedBox(height: 8),
              Text(
                'Small choices. Lasting impact.',
                style: AppTextStyles.body.copyWith(color: AppColors.surface),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
