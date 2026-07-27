import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages Light / Dark theme state.
/// Pre-loaded in main() to avoid first-frame flash.
class ThemeProvider extends ChangeNotifier {
  static const String _key = 'is_dark_mode';

  ThemeMode _themeMode;

  ThemeProvider({bool initialIsDark = false})
      : _themeMode = initialIsDark ? ThemeMode.dark : ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  /// Switch theme and persist the preference immediately.
  Future<void> setTheme(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, mode == ThemeMode.dark);
  }

  void toggleTheme() =>
      setTheme(isDark ? ThemeMode.light : ThemeMode.dark);

  /// Call once at startup (before runApp) to read the saved preference.
  static Future<bool> loadSavedIsDark() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }
}
