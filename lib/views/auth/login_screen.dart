import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/services/session_service.dart';
import 'package:edushare/widgets/custom_button.dart';
import 'package:edushare/widgets/custom_textfield.dart';
import 'package:edushare/widgets/glass_card.dart';
import 'package:edushare/views/auth/register_screen.dart';
import 'package:edushare/views/auth/pending_approval_screen.dart';
import 'package:edushare/views/shell/main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController(); // email OR studentId
  final _passwordController = TextEditingController();

  // UI role keys — 'admin_ui' maps to backend 'faculty_admin'
  // (Super Admin is hidden from login UI)
  String _selectedRole = 'student';
  static const Map<String, String> _uiToBackendRole = {
    'student': 'student',
    'contributor': 'contributor',
    'admin_ui': 'faculty_admin',
  };

  // ─── Student-specific login method ────────────────────────────────────
  String _studentLoginMethod = 'email'; // 'email' | 'studentId'

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    final session = SessionService.instance;
    final savedMethod = await session.getSavedMethod();
    final savedRole = await session.getSavedRole();

    if (!mounted) return;

    setState(() {
      // Restore saved login method for student role
      if (savedRole == 'student' && savedMethod != null) {
        _studentLoginMethod = savedMethod;
      }

      // Restore role selection
      if (savedRole != null) {
        // Map backend role back to UI key
        if (savedRole == 'student') _selectedRole = 'student';
        else if (savedRole == 'contributor') _selectedRole = 'contributor';
        else if (savedRole == 'faculty_admin') _selectedRole = 'admin_ui';
        else _selectedRole = savedRole;
      }
    });
  }

  // ─── Login handler ─────────────────────────────────────────────────────
  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final identifier = _identifierController.text.trim();
    final backendRole = _uiToBackendRole[_selectedRole] ?? _selectedRole;
    final useStudentId = _selectedRole == 'student' && _studentLoginMethod == 'studentId';

    // Pre-check account status
    Map<String, dynamic>? statusData;
    if (useStudentId) {
      statusData = await authService.getAccountStatusByStudentId(identifier);
    } else {
      statusData = await authService.getAccountStatus(identifier);
    }

    if (statusData != null && mounted) {
      final status = statusData['status'] as String?;
      if (status == 'pending' || status == 'rejected') {
        final reason = statusData['rejectionReason'] as String?;
        final isContributor = (statusData['role'] as String?) == 'contributor';
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PendingApprovalScreen(
              name: (statusData?['name'] as String?) ?? '',
              email: (statusData?['email'] as String?) ?? identifier,
              department: (statusData?['department'] as String?) ?? '',
              isPendingContributor: isContributor,
              status: status!,
              rejectionReason: reason,
            ),
          ),
        );
        return;
      } else if (status == 'disabled') {
        _showStatusMessage(
          statusData['message'] as String? ?? 'Your account has been disabled.',
          isError: true,
        );
        return;
      }
    }

    String? error;
    if (useStudentId) {
      error = await authService.loginWithStudentId(
        identifier,
        _passwordController.text,
        backendRole,
        rememberMe: false,
      );
    } else {
      error = await authService.login(
        identifier,
        _passwordController.text,
        backendRole,
        rememberMe: false,
      );
    }

    if (error != null) {
      if (mounted) _showStatusMessage(error, isError: true);
    } else {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()),
          (_) => false,
        );
      }
    }
  }



  void _showStatusMessage(String message, {bool isWarning = false, bool isError = false}) {
    final color = isError
        ? const Color(0xFFEF4444)
        : (isWarning ? const Color(0xFFF59E0B) : AppTheme.primaryColor);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────
  bool get _isStudentRole => _selectedRole == 'student';
  bool get _useStudentIdMethod => _isStudentRole && _studentLoginMethod == 'studentId';

  String get _identifierLabel =>
      _useStudentIdMethod ? 'STUDENT ID' : 'UNIVERSITY EMAIL';

  String get _identifierHint =>
      _useStudentIdMethod ? 'e.g. 21234567890' : 'yourname@bubt.edu.bd';

  IconData get _identifierIcon =>
      _useStudentIdMethod ? Icons.badge_outlined : Icons.email_outlined;

  String? _identifierValidator(String? val) {
    if (_useStudentIdMethod) return AuthService.validateStudentId(val);
    return AuthService.validateEmail(val);
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = context.select<AuthService, bool>((s) => s.isLoading);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.brightness == Brightness.dark
                ? [const Color(0xFF0F172A), const Color(0xFF1E1E38)]
                : [const Color(0xFFF8FAFC), const Color(0xFFEEF2F6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // EduShare Logo
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryColor, AppTheme.accentColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.30),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.accentColor],
                    ).createShader(bounds),
                    child: Text(
                      'EduShare',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  Text(
                    'Share. Learn. Grow.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 32),

                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ─── Role Selection ──────────────────────────
                          Text(
                            'SIGN IN AS',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.brightness == Brightness.dark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Student · Contributor · Admin (Super Admin hidden)
                          Row(
                            children: [
                              _buildRoleChip('student', 'Student',
                                  Icons.person_outline_rounded),
                              const SizedBox(width: 8),
                              _buildRoleChip('contributor', 'Contributor',
                                  Icons.upload_outlined),
                              const SizedBox(width: 8),
                              _buildRoleChip('admin_ui', 'Admin',
                                  Icons.manage_accounts_outlined),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ─── Student login method toggle ─────────────
                          if (_isStudentRole) ...[
                            _buildLoginMethodToggle(theme),
                            const SizedBox(height: 16),
                          ],

                          // ─── Identifier field (email or student ID) ──
                          CustomTextField(
                            label: _identifierLabel,
                            hint: _identifierHint,
                            controller: _identifierController,
                            keyboardType: _useStudentIdMethod
                                ? TextInputType.text
                                : TextInputType.emailAddress,
                            prefixIcon: _identifierIcon,
                            validator: _identifierValidator,
                          ),
                          const SizedBox(height: 20),

                          // ─── Password ────────────────────────────────
                          CustomTextField(
                            label: 'PASSWORD',
                            hint: 'Enter your password',
                            controller: _passwordController,
                            isPassword: true,
                            prefixIcon: Icons.lock_outline_rounded,
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Please enter your password';
                              if (val.length < 6) return 'Password must be at least 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          const SizedBox(height: 20),

                          CustomButton(
                            text: 'Sign In',
                            isLoading: isLoading,
                            onPressed: _handleLogin,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: theme.textTheme.bodyMedium,
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen()),
                          );
                        },
                        child: Text(
                          'Sign Up',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Student login method toggle widget ─────────────────────────────────
  Widget _buildLoginMethodToggle(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final inactiveColor = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildMethodTab('email', 'Email', Icons.email_outlined, inactiveColor),
          _buildMethodTab('studentId', 'Student ID', Icons.badge_outlined, inactiveColor),
        ],
      ),
    );
  }

  Widget _buildMethodTab(String method, String label, IconData icon, Color inactiveColor) {
    final isSelected = _studentLoginMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _studentLoginMethod = method;
          _identifierController.clear(); // clear on toggle to avoid wrong type
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: isSelected ? Colors.white : inactiveColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  // ─── Role chip ──────────────────────────────────────────────────────────
  Widget _buildRoleChip(String role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedRole = role;
          _identifierController.clear();
          if (role != 'student') _studentLoginMethod = 'email';
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : theme.dividerColor,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.primaryColor : theme.disabledColor,
                size: 18,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : theme.textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
