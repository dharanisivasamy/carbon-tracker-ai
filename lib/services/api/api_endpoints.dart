abstract final class ApiEndpoints {
  // Backend base URL. Change ONLY this value to point the app at a
  // different backend:
  //  - Android emulator:        http://10.0.2.2:5000/api
  //  - Physical Android device: http://<your-PC-LAN-IPv4>:5000/api
  //    (the phone and PC must be on the same Wi-Fi/LAN, and the PC's
  //    firewall must allow inbound connections on this port)
  static const baseUrl = 'http://192.168.1.6:5000/api';

  static const login = '/auth/login';
  static const register = '/auth/register';
  static const me = '/auth/me';
  static const trips = '/trips';
  static const tripSummary = '/trips/summary';
  static const tripReports = '/trips/reports';
  static const tripRecommendations = '/trips/recommendations';
}
