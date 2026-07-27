/// session_service.dart — Secure JWT + user session storage
///
/// Uses [flutter_secure_storage] to store the JWT token and the
/// serialised user JSON in the device's encrypted keystore.
/// This is the single source of truth for persistence across restarts.

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

  // ─── Clear all session data ───────────────────────────────────────────

  Future<void> clearAll() async {
    await Future.wait([clearToken(), clearUser()]);
  }
}
