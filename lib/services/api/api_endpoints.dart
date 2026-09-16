import 'package:flutter/foundation.dart';

abstract final class ApiEndpoints {
  // Backend base URL. Change ONLY this value to point the app at a
  // different backend:
  //  - Android emulator:        http://10.0.2.2:5000/api
  //  - Physical Android device: http://<your-PC-LAN-IPv4>:5000/api
  //    (the phone and PC must be on the same Wi-Fi/LAN, and the PC's
  //    firewall must allow inbound connections on this port)
  /// Configure per target instead of committing a stale developer LAN address.
  /// Physical device: --dart-define=API_BASE_URL=http://<PC-LAN-IP>:5000/api
  /// Android emulator defaults to 10.0.2.2. A web browser running on the
  /// backend host defaults to localhost. A physical device must receive an
  /// explicit LAN URL through API_BASE_URL.
  static const _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    return kIsWeb ? 'http://localhost:5000/api' : 'http://10.0.2.2:5000/api';
  }

  static const login = '/auth/login';
  static const register = '/auth/register';
  static const googleLogin = '/auth/google';
  static const me = '/auth/me';
  static const deleteMyData = '/auth/me/data';
  static const trips = '/trips';
  static const tripSummary = '/trips/summary';
  static const tripReports = '/trips/reports';
  static const tripRecommendations = '/trips/recommendations';
  static const tripClassify = '/trips/classify';
}
