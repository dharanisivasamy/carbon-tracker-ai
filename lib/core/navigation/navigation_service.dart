import 'package:flutter/material.dart';

/// App-wide navigator key.
///
/// Services that live outside the widget tree (e.g. the API client
/// reacting to a 401 from an authenticated request) need a way to redirect to the
/// Login screen without a BuildContext being threaded through every API
/// call site. Attaching this key to the top-level [MaterialApp] gives them
/// that access via `navigatorKey.currentState`.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
