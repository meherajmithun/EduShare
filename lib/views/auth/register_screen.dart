import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/department_model.dart';
import 'package:edushare/widgets/custom_button.dart';
import 'package:edushare/widgets/custom_textfield.dart';
import 'package:edushare/widgets/glass_card.dart';
import 'package:edushare/views/shell/main_shell.dart';
import 'package:edushare/views/auth/pending_approval_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _facultyIdController = TextEditingController();
  final _designationController = TextEditingController();

  String _selectedDepartment = 'Computer Science & Engineering';
  String? _selectedDepartmentId;
  String _selectedRole = 'student';

  List<DepartmentModel> _departments = [];
  bool _loadingDepts = true;

  // Static department list (fallback if API fails)
  final List<String> _staticDepartments = [
    'Computer Science & Engineering',
    'Electrical & Electronic Engineering',
    'Business Administration',
    'Civil Engineering',
  ];

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final depts = await FirestoreService().getDepartments();
      if (mounted) {
        setState(() {
          _departments = depts;
          _loadingDepts = false;
          if (depts.isNotEmpty) {
            _selectedDepartmentId = depts.first.id;
            _selectedDepartment = depts.first.name;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDepts = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _facultyIdController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  // 'Admin' in UI = 'faculty_admin' backend role (requires Super Admin approval)
  bool get _isAdminRole => _selectedRole == 'faculty_admin';
  // Backward compat alias used in validators/conditionals below
  bool get _isFacultyAdmin => _isAdminRole;

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);

    if (_isFacultyAdmin) {
      // Faculty Admin registration — no auto-login
      final String? error;
      if (_selectedDepartmentId != null) {
        error = await authService.registerFacultyAdmin(
          name: _nameController.text.trim(),
          facultyId: _facultyIdController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          departmentId: _selectedDepartmentId!,
          designation: _designationController.text.trim(),
        );
      } else {
        error = await authService.register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          department: _selectedDepartment,
          role: 'faculty_admin',
        );
      }

      if (error != null) {
        if (mounted) _showError(error);
      } else {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => PendingApprovalScreen(
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                department: _selectedDepartment,
              ),
            ),
            (route) => false,
          );
        }
      }
    } else {
      // Standard registration (student / legacy admin)
      final error = await authService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        department: _selectedDepartment,
        role: _selectedRole,
      );

      if (error != null) {
        if (mounted) _showError(error);
      } else if (authService.isLastRegistrationPending) {
        // Contributor path — account needs Faculty Admin approval
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => PendingApprovalScreen(
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                department: _selectedDepartment,
                isPendingContributor: true,
              ),
            ),
            (route) => false,
          );
        }
      } else {
        // Student / legacy admin — logged in immediately
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainShell()),
            (route) => false,
          );
        }
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = context.select<AuthService, bool>((s) => s.isLoading);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Join EduShare',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect, share, and access study materials',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),

                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ─── Name ──────────────────────────────────────
                          CustomTextField(
                            label: 'FULL NAME',
                            hint: 'Enter your full name',
                            controller: _nameController,
                            prefixIcon: Icons.person_outline_rounded,
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Please enter your name';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // ─── Email ─────────────────────────────────────
                          CustomTextField(
                            label: 'UNIVERSITY EMAIL',
                            hint: 'yourname@bubt.edu.bd',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_outlined,
                            validator: AuthService.validateEmail,
                          ),
                          const SizedBox(height: 20),

                          // ─── Password ──────────────────────────────────
                          CustomTextField(
                            label: 'PASSWORD',
                            hint: 'Enter a strong password',
                            controller: _passwordController,
                            isPassword: true,
                            prefixIcon: Icons.lock_outline_rounded,
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Please enter a password';
                              if (val.length < 6) return 'Password must be at least 6 characters';
                              return null;
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Text(
                              'Use at least 6 characters with a mix of letters and numbers',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 11,
                                color: theme.brightness == Brightness.dark
                                    ? AppTheme.darkTextSecondary.withOpacity(0.7)
                                    : AppTheme.lightTextSecondary.withOpacity(0.7),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ─── Department ────────────────────────────────
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DEPARTMENT',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.brightness == Brightness.dark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_loadingDepts)
                                const Center(
                                  child: SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.primaryColor),
                                  ),
                                )
                              else if (_departments.isNotEmpty)
                                DropdownButtonFormField<String>(
                                  value: _selectedDepartmentId,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 16),
                                  ),
                                  icon: const Icon(Icons.arrow_drop_down_rounded, size: 28),
                                  items: _departments.map((dept) {
                                    return DropdownMenuItem(
                                      value: dept.id,
                                      child: Text(dept.name,
                                          style: theme.textTheme.bodyMedium),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      final dept = _departments.firstWhere(
                                          (d) => d.id == val);
                                      setState(() {
                                        _selectedDepartmentId = val;
                                        _selectedDepartment = dept.name;
                                      });
                                    }
                                  },
                                  validator: (val) {
                                    if (_isFacultyAdmin && val == null) {
                                      return 'Please select a department';
                                    }
                                    return null;
                                  },
                                )
                              else
                                DropdownButtonFormField<String>(
                                  value: _selectedDepartment,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 16),
                                  ),
                                  icon: const Icon(Icons.arrow_drop_down_rounded, size: 28),
                                  items: _staticDepartments.map((dept) {
                                    return DropdownMenuItem(
                                      value: dept,
                                      child: Text(dept,
                                          style: theme.textTheme.bodyMedium),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedDepartment = val);
                                    }
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ─── Role Selection ────────────────────────────
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'JOIN AS',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.brightness == Brightness.dark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildRoleOption('student', 'Student',
                                      Icons.person_outline_rounded),
                                  const SizedBox(width: 8),
                                  _buildRoleOption('contributor', 'Contributor',
                                      Icons.upload_outlined),
                                  const SizedBox(width: 8),
                                  _buildRoleOption('faculty_admin', 'Admin',
                                      Icons.admin_panel_settings_outlined),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ─── Admin extra fields ─────────────────
                          if (_isFacultyAdmin) ...[
                            CustomTextField(
                              label: 'FACULTY ID',
                              hint: 'e.g. FAC-2024-001',
                              controller: _facultyIdController,
                              prefixIcon: Icons.badge_outlined,
                              validator: (val) {
                                if (_isFacultyAdmin &&
                                    (val == null || val.isEmpty)) {
                                  return 'Please enter your Faculty ID';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            CustomTextField(
                              label: 'DESIGNATION',
                              hint: 'e.g. Assistant Professor',
                              controller: _designationController,
                              prefixIcon: Icons.work_outline_rounded,
                              validator: (val) {
                                if (_isFacultyAdmin &&
                                    (val == null || val.isEmpty)) {
                                  return 'Please enter your designation';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFF59E0B).withOpacity(0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      size: 16, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Your admin application will be reviewed by the Super Admin before you can log in.',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontSize: 12,
                                        color: const Color(0xFFF59E0B),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          CustomButton(
                            text: _isFacultyAdmin
                                ? 'Submit Application'
                                : 'Create Account',
                            isLoading: isLoading,
                            onPressed: _handleRegister,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleOption(String role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
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
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
