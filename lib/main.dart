import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'package:carbon_tracker/core/navigation/navigation_service.dart';
import 'package:carbon_tracker/core/routes/app_routes.dart';
import 'package:carbon_tracker/core/theme/app_theme.dart';
import 'package:carbon_tracker/repositories/trip_repository.dart';
import 'package:carbon_tracker/repositories/labelled_window_repository.dart';
import 'package:carbon_tracker/services/api/api_client.dart';
import 'package:carbon_tracker/services/api/api_endpoints.dart';
import 'package:carbon_tracker/services/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await TripRepository.instance.initialize();
  await LabelledWindowRepository.instance.initialize();
  debugPrint('[API] Base URL: ${ApiEndpoints.baseUrl}');
  _wireSessionExpiryHandling();
  runApp(const CarbonTrackerApp());
}

/// Wires the API layer's 401-on-authenticated-request hook to a single,
/// app-wide response: clear stored auth data and return to the Login
/// screen with a readable message - no matter which screen or API call
/// triggered it. A guard flag stops parallel failing requests (e.g. a
/// screen that fires several API calls at once) from redirecting more
/// than once.
void _wireSessionExpiryHandling() {
  var handlingExpiry = false;
  ApiClient.onSessionExpired = () async {
    if (handlingExpiry) return;
    handlingExpiry = true;
    try {
      await AuthService.instance.logout();
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
        arguments: 'Session expired. Please log in again.',
      );
    } finally {
      handlingExpiry = false;
    }
  };
}

class CarbonTrackerApp extends StatelessWidget {
  const CarbonTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Carbon Tracker',
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
