import 'package:flutter/foundation.dart';

/// Lightweight debug-only logger.
///
/// Use this instead of `print()` for diagnostic logging. It is a no-op in
/// release builds (kDebugMode is false), and callers must never pass
/// secrets (passwords, tokens) to it.
void logDebug(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}
