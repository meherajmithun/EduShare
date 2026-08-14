import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages Light / Dark / System theme state.
/// Pre-loaded in main() to avoid first-frame flash.
class ThemeProvider extends ChangeNotifier {
  // New string key that can store 'light', 'dark', or 'system'
  static const String _key = 'theme_mode';
  // Legacy bool key — kept only for migration read
  static const String _legacyKey = 'is_dark_mode';

  ThemeMode _themeMode;

  ThemeProvider({ThemeMode initialMode = ThemeMode.dark})
      : _themeMode = initialMode;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  /// Switch theme and persist the preference immediately.
  Future<void> setTheme(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _modeToString(mode));
  }

  void toggleTheme() =>
      setTheme(isDark ? ThemeMode.light : ThemeMode.dark);

  /// Call once at startup (before runApp) to read the saved preference.
  /// Migrates the legacy bool key if found.
  static Future<ThemeMode> loadSavedMode() async {
    final prefs = await SharedPreferences.getInstance();
    // Prefer new key
    final saved = prefs.getString(_key);
    if (saved != null) return _modeFromString(saved);
    // Migrate legacy bool key
    final legacyDark = prefs.getBool(_legacyKey);
    if (legacyDark != null) return legacyDark ? ThemeMode.dark : ThemeMode.light;
    return ThemeMode.dark; // sensible default
  }

  /// Convenience for callers that only care about isDark at startup.
  static Future<bool> loadSavedIsDark() async {
    final mode = await loadSavedMode();
    return mode == ThemeMode.dark;
  }

  static String _modeToString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light: return 'light';
      case ThemeMode.system: return 'system';
      default: return 'dark';
    }
  }

  static ThemeMode _modeFromString(String s) {
    switch (s) {
      case 'light': return ThemeMode.light;
      case 'system': return ThemeMode.system;
      default: return ThemeMode.dark;
    }
  }
}
