import 'package:flutter/material.dart';

import '../../screens/auth/login/screen.dart';
import '../../screens/auth/register/screen.dart';
import '../../screens/dashboard/screen.dart';
import '../../screens/profile/screen.dart';
import '../../screens/reports/screen.dart';
import '../../screens/settings/screen.dart';
import '../../screens/recommendations/screen.dart';
import '../../screens/trips/add_trip_screen.dart';
import '../../screens/trips/screen.dart';
import '../../screens/onboarding/screen.dart';
import '../../screens/splash/screen.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const tripHistory = '/trips';
  static const addTrip = '/trips/add';
  static const reports = '/reports';
  static const recommendations = '/recommendations';
  static const profile = '/profile';
  static const settings = '/settings';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final page = switch (settings.name) {
      '/' => const SplashScreen(),
      '/onboarding' => const OnboardingScreen(),
      '/login' => const LoginScreen(),
      '/register' => const RegisterScreen(),
      '/dashboard' => const DashboardScreen(),
      '/trips' => const TripHistoryScreen(),
      '/trips/add' => const AddTripScreen(),
      '/reports' => const ReportsScreen(),
      '/recommendations' => const RecommendationsScreen(),
      '/profile' => const ProfileScreen(),
      '/settings' => const SettingsScreen(),
      _ => const SplashScreen(),
    };
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
