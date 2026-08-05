/// session_service.dart — Secure JWT + user session storage
///
/// Uses [flutter_secure_storage] to store the JWT token and the
/// serialised user JSON in the device's encrypted keystore.
/// This is the single source of truth for persistence across restarts.
///
/// Remember Me stores the login identifier (email or studentId), role, and
/// login method — NEVER the password. Quick Login (biometric) flag is stored
/// as a plain boolean string.

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:edushare/models/user_model.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  // Android: uses EncryptedSharedPreferences
  // iOS: uses Keychain
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _tokenKey = 'jwt_token';
  static const _userKey = 'current_user';

  // ─── Remember Me ──────────────────────────────────────────────────────
  static const _rememberMeKey = 'remember_me';
  static const _savedIdentifierKey = 'saved_login_identifier'; // email or studentId — NEVER password
  static const _savedRoleKey = 'saved_login_role';             // 'student' | 'contributor' | 'admin_ui'
  static const _savedMethodKey = 'saved_login_method';         // 'email' | 'studentId'

  // ─── Quick Login (Biometric) ──────────────────────────────────────────
  static const _quickLoginEnabledKey = 'quick_login_enabled';

  // ─── Token ────────────────────────────────────────────────────────────

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // ─── User ─────────────────────────────────────────────────────────────

  Future<void> saveUser(UserModel user) async {
    final json = jsonEncode(user.toJson());
    await _storage.write(key: _userKey, value: json);
  }

  Future<UserModel?> getUser() async {
    final json = await _storage.read(key: _userKey);
    if (json == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUser() async {
    await _storage.delete(key: _userKey);
  }

  // ─── Remember Me ──────────────────────────────────────────────────────

  /// Save "Remember Me" preference and the login identifier.
  /// [identifier] is the email or student ID — NEVER the password.
  Future<void> saveRememberMe({
    required bool rememberMe,
    required String identifier,
    required String role,
    required String method, // 'email' or 'studentId'
  }) async {
    await Future.wait([
      _storage.write(key: _rememberMeKey, value: rememberMe.toString()),
      _storage.write(key: _savedIdentifierKey, value: identifier),
      _storage.write(key: _savedRoleKey, value: role),
      _storage.write(key: _savedMethodKey, value: method),
    ]);
  }

  Future<bool> getRememberMe() async {
    final val = await _storage.read(key: _rememberMeKey);
    return val == 'true';
  }

  Future<String?> getSavedIdentifier() async {
    return _storage.read(key: _savedIdentifierKey);
  }

  Future<String?> getSavedRole() async {
    return _storage.read(key: _savedRoleKey);
  }

  Future<String?> getSavedMethod() async {
    return _storage.read(key: _savedMethodKey);
  }

  Future<void> clearRememberMe() async {
    await Future.wait([
      _storage.delete(key: _rememberMeKey),
      _storage.delete(key: _savedIdentifierKey),
      _storage.delete(key: _savedRoleKey),
      _storage.delete(key: _savedMethodKey),
    ]);
  }

  // ─── Quick Login (Biometric) ──────────────────────────────────────────

  Future<void> setQuickLoginEnabled(bool enabled) async {
    await _storage.write(key: _quickLoginEnabledKey, value: enabled.toString());
  }

  Future<bool> getQuickLoginEnabled() async {
    final val = await _storage.read(key: _quickLoginEnabledKey);
    return val == 'true';
  }

  // ─── Clear all session data ───────────────────────────────────────────

  Future<void> clearAll() async {
    await Future.wait([
      clearToken(),
      clearUser(),
      // Do NOT clear Remember Me or Quick Login on signOut — those are user preferences
    ]);
  }

  /// Full factory reset — clears everything including Remember Me and Quick Login.
  Future<void> clearAllPreferences() async {
    await Future.wait([
      clearToken(),
      clearUser(),
      clearRememberMe(),
      _storage.delete(key: _quickLoginEnabledKey),
    ]);
  }
}
