/// auth_service.dart — Authentication service backed by the Node.js REST API
///
/// Supports 5 roles: student, contributor, admin, faculty_admin, super_admin.
///
/// registerFacultyAdmin() does NOT log the user in — it submits the
/// application and returns success/error without persisting a token.
///
/// New in this version:
///   - loginWithStudentId()  — student-only alternative login
///   - getAccountStatusByStudentId() — pre-check by student ID
///   - rememberMe support   — persists identifier+role to secure storage (NEVER password)
///   - biometric / Quick Login — uses local_auth to re-authenticate existing token

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/core/services/api_client.dart';
import 'package:edushare/core/services/session_service.dart';
import 'package:edushare/core/exceptions/app_exception.dart';

class AuthService extends ChangeNotifier {
  final _api = ApiClient.instance;
  final _session = SessionService.instance;
  final _localAuth = LocalAuthentication();

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isLastRegistrationPending = false;

  // ─── Quick Login state ─────────────────────────────────────────────────
  bool _quickLoginEnabled = false;
  bool _biometricsAvailable = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLastRegistrationPending => _isLastRegistrationPending;
  bool get quickLoginEnabled => _quickLoginEnabled;
  bool get biometricsAvailable => _biometricsAvailable;

  // ─── Allowed university email domains (client-side pre-validation) ─────
  static const List<String> allowedDomains = ['bubt.edu.bd'];
  static const List<String> blockedDomains = [
    'gmail.com', 'yahoo.com', 'outlook.com',
    'hotmail.com', 'mail.com', 'protonmail.com',
  ];

  static bool isAllowedEmail(String email) {
    final lower = email.toLowerCase().trim();
    for (final b in blockedDomains) {
      if (lower.endsWith('@$b')) return false;
    }
    for (final a in allowedDomains) {
      if (lower.endsWith('@$a')) return true;
    }
    return false;
  }

  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) return 'Please enter your email';
    if (!email.contains('@')) return 'Please enter a valid email address';
    final domain = email.split('@').last.toLowerCase();
    for (final b in blockedDomains) {
      if (domain == b) return 'Personal emails are not allowed. Use your university email (@bubt.edu.bd)';
    }
    if (!isAllowedEmail(email)) return 'Only university emails are allowed (e.g. name@bubt.edu.bd)';
    return null;
  }

  static String? validateStudentId(String? id) {
    if (id == null || id.trim().isEmpty) return 'Please enter your Student ID';
    if (id.trim().length < 4) return 'Student ID must be at least 4 characters';
    return null;
  }

  // ─── Session restoration (called at app startup) ───────────────────────
  Future<void> restoreSession() async {
    final token = await _session.getToken();

    // Load Quick Login preference
    _quickLoginEnabled = await _session.getQuickLoginEnabled();

    // Check biometrics availability
    try {
      _biometricsAvailable = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      _biometricsAvailable = false;
    }

    if (token == null) return;

    try {
      final data = await _api.get('/api/auth/profile');
      _currentUser = UserModel.fromJson(data as Map<String, dynamic>);
      await _session.saveUser(_currentUser!);
    } on UnauthorizedException {
      await _session.clearAll();
      _currentUser = null;
    } catch (_) {
      _currentUser = await _session.getUser();
    }
  }

  // ─── Biometric / Quick Login ───────────────────────────────────────────
  /// Returns true if biometric authentication succeeded.
  Future<bool> authenticateWithBiometrics() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Sign in to EduShare',
        options: const AuthenticationOptions(
          biometricOnly: false, // allow PIN/pattern fallback
          stickyAuth: true,
        ),
      );
      return authenticated;
    } catch (_) {
      return false;
    }
  }

  /// Enable or disable Quick Login and persist the preference.
  Future<void> setQuickLoginEnabled(bool enabled) async {
    _quickLoginEnabled = enabled;
    await _session.setQuickLoginEnabled(enabled);
    notifyListeners();
  }

  // ─── Check Account Status by Email ────────────────────────────────────
  Future<Map<String, dynamic>?> getAccountStatus(String email) async {
    try {
      final data = await _api.get(
        '/api/auth/account-status?email=${Uri.encodeComponent(email.trim().toLowerCase())}',
        auth: false,
      );
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── Check Account Status by Student ID ───────────────────────────────
  Future<Map<String, dynamic>?> getAccountStatusByStudentId(String studentId) async {
    try {
      final data = await _api.get(
        '/api/auth/account-status?studentId=${Uri.encodeComponent(studentId.trim())}',
        auth: false,
      );
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── Login (email + password) ──────────────────────────────────────────
  Future<String?> login(
    String email,
    String password,
    String role, {
    bool rememberMe = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.post(
        '/api/auth/login',
        {'email': email.trim().toLowerCase(), 'password': password, 'role': role},
        auth: false,
      );

      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

      await _session.saveToken(token);
      await _session.saveUser(user);

      // Remember Me — persist identifier (never password)
      if (rememberMe) {
        await _session.saveRememberMe(
          rememberMe: true,
          identifier: email.trim().toLowerCase(),
          role: role,
          method: 'email',
        );
      } else {
        await _session.clearRememberMe();
      }

      _currentUser = user;
      _isLoading = false;
      notifyListeners();
      return null;
    } on AppException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // ─── Login (studentId + password) — students only ─────────────────────
  Future<String?> loginWithStudentId(
    String studentId,
    String password,
    String role, {
    bool rememberMe = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.post(
        '/api/auth/login',
        {'studentId': studentId.trim(), 'password': password, 'role': role},
        auth: false,
      );

      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

      await _session.saveToken(token);
      await _session.saveUser(user);

      // Remember Me — persist student ID (never password)
      if (rememberMe) {
        await _session.saveRememberMe(
          rememberMe: true,
          identifier: studentId.trim(),
          role: role,
          method: 'studentId',
        );
      } else {
        await _session.clearRememberMe();
      }

      _currentUser = user;
      _isLoading = false;
      notifyListeners();
      return null;
    } on AppException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // ─── Register (student, contributor, legacy admin) ──────────────────────
  //
  // Contributor path: backend returns {pending:true} — no token issued.
  // Student path: backend returns {token, user} — logged in immediately.
  // Optional studentId is passed for student registration.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String department,
    required String role,
    String? studentId,
  }) async {
    final emailError = validateEmail(email);
    if (emailError != null) return emailError;

    _isLastRegistrationPending = false;
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.post(
        '/api/auth/register',
        {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'role': role,
          'department': department,
          if (studentId != null && studentId.trim().isNotEmpty)
            'studentId': studentId.trim(),
        },
        auth: false,
      );

      // Contributor pending path — no token in response
      if (data is Map && data['pending'] == true) {
        _isLastRegistrationPending = true;
        _isLoading = false;
        notifyListeners();
        return null; // success, but pending
      }

      // Active path (student / legacy admin)
      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

      await _session.saveToken(token);
      await _session.saveUser(user);

      _currentUser = user;
      _isLoading = false;
      notifyListeners();
      return null;
    } on AppException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // ─── Register Faculty Admin (pending approval — does NOT log in) ───────
  /// Submits a Faculty Admin application. Returns null on success, error string on failure.
  /// The user is NOT logged in after this — they must await Super Admin approval.
  Future<String?> registerFacultyAdmin({
    required String name,
    required String facultyId,
    required String email,
    required String password,
    required String departmentId,
    required String designation,
    String? profilePhotoUrl,
  }) async {
    final emailError = validateEmail(email);
    if (emailError != null) return emailError;

    _isLoading = true;
    notifyListeners();

    try {
      await _api.post(
        '/api/auth/register-faculty-admin',
        {
          'name': name.trim(),
          'facultyId': facultyId.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'departmentId': departmentId,
          'designation': designation.trim(),
          if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty)
            'profilePhotoUrl': profilePhotoUrl,
        },
        auth: false,
      );

      _isLoading = false;
      notifyListeners();
      return null; // Success — but no token
    } on AppException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // ─── Update Profile ──────────────────────────────────────────────────
  Future<String?> updateProfile({
    String? name,
    String? bio,
    String? designation,
    String? profilePhotoUrl,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.put('/api/auth/profile', {
        if (name != null) 'name': name.trim(),
        if (bio != null) 'bio': bio.trim(),
        if (designation != null) 'designation': designation.trim(),
        if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl.trim(),
      });

      final updatedUser = UserModel.fromJson(data as Map<String, dynamic>);
      await _session.saveUser(updatedUser);
      _currentUser = updatedUser;
      _isLoading = false;
      notifyListeners();
      return null;
    } on AppException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Failed to update profile. Please try again.';
    }
  }

  // ─── Upload Profile Photo ──────────────────────────────────────────────
  Future<String?> updateProfilePhotoBytes(Uint8List bytes, String fileName) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.postMultipartBytes(
        '/api/auth/profile/photo',
        bytes: bytes,
        fileName: fileName,
        fileField: 'photo',
      );

      final photoUrl = data['profilePhotoUrl'] as String?;
      if (photoUrl != null && _currentUser != null) {
        _currentUser = _currentUser!.copyWith(profilePhotoUrl: photoUrl);
        await _session.saveUser(_currentUser!);
      }
      _isLoading = false;
      notifyListeners();
      return null;
    } on AppException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Failed to upload photo. Please try again.';
    }
  }

  // ─── Sign out ──────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _session.clearAll(); // clears token + user, keeps rememberMe + quickLogin prefs
    _currentUser = null;
    notifyListeners();
  }
}
