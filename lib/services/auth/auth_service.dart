import 'package:carbon_tracker/services/api/api_service.dart';
import 'package:carbon_tracker/services/api/api_client.dart';
import 'package:carbon_tracker/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _tokenKey = 'auth_token';
  static const _nameKey = 'auth_name';
  static const _emailKey = 'auth_email';
  static const _idKey = 'auth_id';

  Future<String?> get token async => (await SharedPreferences.getInstance()).getString(_tokenKey);

  /// True if a stored token exists. Combined with [token] being sent on
  /// every protected request, this is what the app uses to decide whether
  /// a user is authenticated (e.g. on splash / app start).
  Future<bool> get isLoggedIn async => (await token) != null;

  Future<void> login(String email, String password) async {
    logDebug('[AUTH] Login request started');
    final data = await ApiService.instance.login(email, password);
    await _save(data);
    logDebug('[AUTH] Login successful');
  }

  Future<void> register(String name, String email, String password) async {
    logDebug('[AUTH] Registration request started');
    final data = await ApiService.instance.register(name, email, password);
    await _save(data);
    logDebug('[AUTH] Registration successful');
  }

  Future<String?> get currentUserName async => (await SharedPreferences.getInstance()).getString(_nameKey);
  Future<String?> get currentUserEmail async => (await SharedPreferences.getInstance()).getString(_emailKey);
  Future<String?> get currentUserId async => (await SharedPreferences.getInstance()).getString(_idKey);

  /// Persists the token + user info returned by login/register.
  ///
  /// Tolerant of the response being wrapped in a `data` object (the actual
  /// backend contract), but throws a clear [ApiException] instead of a raw
  /// TypeError/null-check crash if the shape is ever unexpected.
  Future<void> _save(Map<String, dynamic> response) async {
    try {
      final data = response['data'] as Map<String, dynamic>? ?? response;
      final user = data['user'] as Map<String, dynamic>;
      final token = data['token'] as String;
      final name = user['name'] as String;
      final email = user['email'] as String;
      final id = (user['id'] ?? user['_id']) as String;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_nameKey, name);
      await prefs.setString(_emailKey, email);
      await prefs.setString(_idKey, id);
    } catch (_) {
      throw ApiException('Received an unexpected response from the server.');
    }
  }

  /// Confirms the stored token is still valid according to the backend.
  ///
  /// Returns false only when the backend explicitly rejects the token
  /// (401), in which case stored auth data is cleared so the app never
  /// treats a stale local token as a valid session. Network errors are
  /// treated as "session unknown" rather than "invalid", so a user who is
  /// simply offline is not logged out and can keep using cached local data.
  Future<bool> validateSession() async {
    final storedToken = await token;
    if (storedToken == null) return false;
    try {
      await ApiService.instance.me(storedToken);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await logout();
        return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_idKey);
    logDebug('[AUTH] Logged out');
  }
}
