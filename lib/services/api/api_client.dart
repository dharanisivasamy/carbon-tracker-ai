import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_endpoints.dart';

/// Exception thrown for any failed API call.
///
/// Carries the [message] that should be shown to the user, the HTTP
/// [statusCode] when one was received, and flags describing the failure
/// category so callers can branch on it if needed (e.g. to trigger an
/// offline fallback).
class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.isNetworkError = false,
    this.isTimeout = false,
  });

  final String message;
  final int? statusCode;
  final bool isNetworkError;
  final bool isTimeout;

  /// Human readable message. Overriding toString() is required so that
  /// `catch (e) { print(e); }` / `e.toString()` show the real error instead
  /// of the default `Instance of 'ApiException'`.
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Invoked whenever a request that carried an auth [token] comes back
  /// with a 401. This means the stored session is no longer valid (expired
  /// or revoked), as opposed to a 401 from the login endpoint itself
  /// (which is a plain "wrong credentials" and never carries a token).
  /// Set once from app startup (see main.dart) so every screen gets
  /// consistent "session expired -> back to Login" behaviour without
  /// each call site having to check for it individually.
  static void Function()? onSessionExpired;

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final uri = Uri.parse('${ApiEndpoints.baseUrl}$path');

    http.StreamedResponse response;
    try {
      final httpRequest = http.Request(method, uri)
        ..headers.addAll({
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        })
        ..body = jsonEncode(body ?? {});

      response = await _client
          .send(httpRequest)
          .timeout(timeout);
    } on TimeoutException {
      throw ApiException(
        'Request timed out after ${timeout.inSeconds}s. The server may be reachable but slow.',
        isTimeout: true,
      );
    } on SocketException {
      throw ApiException(
        'Server unreachable. Check the API base URL, backend process, Wi-Fi/LAN, and firewall.',
        isNetworkError: true,
      );
    } on HandshakeException {
      throw ApiException(
        'Unable to establish a secure connection to the server.',
        isNetworkError: true,
      );
    } on http.ClientException {
      throw ApiException(
        'Server unreachable. The backend did not accept a connection.',
        isNetworkError: true,
      );
    }

    final rawBody = await response.stream.bytesToString();

    Map<String, dynamic>? data;
    if (rawBody.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBody);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } on FormatException {
        data = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (data == null) {
        throw ApiException(
          'Received an unexpected response from the server.',
          statusCode: response.statusCode,
        );
      }
      return data;
    }

    if (response.statusCode == 401 && token != null) {
      // An authenticated request was rejected: the stored token is
      // expired/invalid, not a login-form mistake (login never sends a
      // token), so trigger the app-wide "session expired" handler.
      onSessionExpired?.call();
    }

    final serverMessage = data?['message'] as String?;
    throw ApiException(
      serverMessage ?? _defaultMessageFor(response.statusCode),
      statusCode: response.statusCode,
    );
  }

  String _defaultMessageFor(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your details and try again.';
      case 401:
        return 'Invalid email or password.';
      case 403:
        return 'You do not have permission to do that.';
      case 404:
        return 'The requested resource was not found.';
      case 409:
        return 'That email is already registered.';
      case 500:
      default:
        return statusCode >= 500
            ? 'Server error. Please try again later.'
            : 'Something went wrong. Please try again.';
    }
  }
}
