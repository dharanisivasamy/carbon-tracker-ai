import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:carbon_tracker/services/api/api_service.dart';
import 'package:carbon_tracker/services/api/api_client.dart';
import 'package:carbon_tracker/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A user-facing failure from the Google-to-Firebase sign-in step.
///
/// The backend exchanges a verified Firebase identity for the existing app JWT.
class GoogleAuthenticationException implements Exception {
  const GoogleAuthenticationException(this.message, {this.isCancelled = false});

  final String message;
  final bool isCancelled;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _tokenKey = 'auth_token';
  static const _nameKey = 'auth_name';
  static const _emailKey = 'auth_email';
  static const _idKey = 'auth_id';

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static Future<void>? _googleSignInInitialization;

  Future<String?> get token async =>
      (await SharedPreferences.getInstance()).getString(_tokenKey);

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

  /// Completes Phase 1 of Google sign-in: Google account selection followed by
  /// Firebase Authentication. The Firebase ID token stays on-device for now;
  /// a later backend phase will exchange it for the app's existing JWT.
  Future<void> signInWithGoogle() async {
    try {
      final UserCredential userCredential;
      if (kIsWeb) {
        // Uri.base.origin is the Dart web runtime equivalent of
        // window.location.origin. It contains no credentials or tokens.
        logDebug('[AUTH] Google Sign-In web origin: ${Uri.base.origin}');
        userCredential = await FirebaseAuth.instance.signInWithPopup(
          GoogleAuthProvider(),
        );
      } else {
        await (_googleSignInInitialization ??= _googleSignIn.initialize());
        if (!_googleSignIn.supportsAuthenticate()) {
          throw const GoogleAuthenticationException(
            'Google Sign-In is not available on this platform yet.',
          );
        }
        final googleAccount = await _googleSignIn.authenticate();
        final googleAuthentication = googleAccount.authentication;
        final googleIdToken = googleAuthentication.idToken;
        if (googleIdToken == null || googleIdToken.isEmpty) {
          throw const GoogleAuthenticationException(
            'Google Sign-In did not return an identity token. Please try again.',
          );
        }
        userCredential = await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(idToken: googleIdToken),
        );
      }
      final user = userCredential.user;

      if (user == null) {
        throw const GoogleAuthenticationException(
          'Firebase did not return a signed-in user. Please try again.',
        );
      }

      // Deliberately log only safe status values. Never log the ID token,
      // OAuth credentials, or other authentication secrets.
      logDebug('[AUTH] Firebase Google authentication succeeded');
      logDebug('[AUTH] Firebase UID exists: ${user.uid.isNotEmpty}');
      logDebug(
        '[AUTH] Firebase email exists: ${user.email?.isNotEmpty ?? false}',
      );
      final firebaseIdToken = await user.getIdToken();
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        throw const GoogleAuthenticationException(
          'Firebase did not return an identity token. Please try again.',
        );
      }
      final response = await ApiService.instance.googleLogin(firebaseIdToken);
      await _save(response);
      logDebug('[AUTH] Google account exchanged for application session');
    } on GoogleAuthenticationException {
      rethrow;
    } on ApiException {
      rethrow;
    } on GoogleSignInException catch (error) {
      throw _googleSignInFailure(error);
    } on FirebaseAuthException catch (error) {
      throw _firebaseAuthenticationFailure(error);
    } catch (_) {
      throw const GoogleAuthenticationException(
        'Google Sign-In could not be completed. Check your connection and try again.',
      );
    }
  }

  GoogleAuthenticationException _googleSignInFailure(
    GoogleSignInException error,
  ) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return const GoogleAuthenticationException(
          'Google Sign-In was cancelled.',
          isCancelled: true,
        );
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return const GoogleAuthenticationException(
          'Google Sign-In is not configured correctly for this app.',
        );
      case GoogleSignInExceptionCode.uiUnavailable:
        return const GoogleAuthenticationException(
          'Google account selection is unavailable. Please try again.',
        );
      case GoogleSignInExceptionCode.interrupted:
        return const GoogleAuthenticationException(
          'Google Sign-In was interrupted. Please try again.',
        );
      case GoogleSignInExceptionCode.userMismatch:
        return const GoogleAuthenticationException(
          'The selected Google account could not be used. Please try again.',
        );
      case GoogleSignInExceptionCode.unknownError:
        final description = error.description?.toLowerCase() ?? '';
        if (description.contains('no credential') ||
            description.contains('no account')) {
          return const GoogleAuthenticationException(
            'No Google account is available on this device.',
          );
        }
        if (description.contains('network')) {
          return const GoogleAuthenticationException(
            'Network error while contacting Google. Check your connection and try again.',
          );
        }
        return const GoogleAuthenticationException(
          'Google Sign-In failed. Please try again.',
        );
    }
  }

  GoogleAuthenticationException _firebaseAuthenticationFailure(
    FirebaseAuthException error,
  ) {
    return switch (error.code) {
      'network-request-failed' => const GoogleAuthenticationException(
        'Network error while contacting Firebase. Check your connection and try again.',
      ),
      'operation-not-allowed' => const GoogleAuthenticationException(
        'Google Sign-In is not enabled in Firebase Authentication.',
      ),
      'unauthorized-domain' => const GoogleAuthenticationException(
        'This web origin is not authorized for Firebase Authentication.',
      ),
      'popup-blocked' => const GoogleAuthenticationException(
        'The browser blocked the Google Sign-In popup. Allow popups and try again.',
      ),
      'popup-closed-by-user' => const GoogleAuthenticationException(
        'Google Sign-In was cancelled.',
        isCancelled: true,
      ),
      'account-exists-with-different-credential' =>
        const GoogleAuthenticationException(
          'This email is already associated with a different sign-in method.',
        ),
      'user-disabled' => const GoogleAuthenticationException(
        'This Firebase account has been disabled.',
      ),
      _ => const GoogleAuthenticationException(
        'Firebase could not authenticate the selected Google account. Please try again.',
      ),
    };
  }

  Future<String?> get currentUserName async =>
      (await SharedPreferences.getInstance()).getString(_nameKey);
  Future<String?> get currentUserEmail async =>
      (await SharedPreferences.getInstance()).getString(_emailKey);
  Future<String?> get currentUserId async =>
      (await SharedPreferences.getInstance()).getString(_idKey);

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
