/// main.dart — EduShare app entry point

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/providers/theme_provider.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/services/notification_service.dart';
import 'package:edushare/views/auth/login_screen.dart';
import 'package:edushare/views/shell/main_shell.dart';
import 'package:edushare/views/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final initialIsDark = await ThemeProvider.loadSavedIsDark();

  final authService = AuthService();
  await authService.restoreSession();

  // Pre-create notification service so it's available immediately after login
  final notificationService = NotificationService();
  if (authService.currentUser != null) {
    // Refresh badge count on app startup if a session was restored
    notificationService.refreshUnreadCount();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<NotificationService>.value(
            value: notificationService),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(initialIsDark: initialIsDark),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode =
        context.select<ThemeProvider, ThemeMode>((p) => p.themeMode);
    return MaterialApp(
      title: 'EduShare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 300),
      themeAnimationCurve: Curves.easeInOut,
      home: const SplashScreen(),
    );
  }
}

/// Routes authenticated users to [MainShell], unauthenticated to [LoginScreen].
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.select<AuthService, bool>(
      (s) => s.currentUser != null,
    );
    return isLoggedIn ? const MainShell() : const LoginScreen();
  }
}
