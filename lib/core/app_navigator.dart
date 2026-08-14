/// app_navigator.dart — Global navigator key for the EduShare app.
///
/// Keeping this in its own file avoids circular imports between
/// main.dart (which imports auth_service) and auth_service (which
/// needs the key for post-logout navigation).

import 'package:flutter/material.dart';

/// Attach this key to MaterialApp.navigatorKey.
/// AuthService.signOut() uses it to pop the whole stack → LoginScreen.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
