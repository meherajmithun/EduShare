import 'package:flutter/material.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/views/auth/login_screen.dart';

/// Shown after a registration with pending approval, or when login is blocked.
///
/// [status] can be:
///   - 'pending'  → yellow, awaiting approval
///   - 'rejected' → red, shows rejection reason
///   - 'disabled' → grey, account disabled
class PendingApprovalScreen extends StatelessWidget {
  final String name;
  final String email;
  final String department;
  final bool isPendingContributor;

  /// 'pending' | 'rejected' | 'disabled'
  final String status;
  final String? rejectionReason;

  const PendingApprovalScreen({
    Key? key,
    this.name = '',
    this.email = '',
    this.department = '',
    this.isPendingContributor = false,
    this.status = 'pending',
    this.rejectionReason,
  }) : super(key: key);

  bool get isRejected => status == 'rejected';
  bool get isDisabled => status == 'disabled';
  bool get isPending => status == 'pending';

  Color get _statusColor {
    if (isRejected) return const Color(0xFFEF4444);
    if (isDisabled) return const Color(0xFF6B7280);
    return const Color(0xFFF59E0B);
  }

  IconData get _statusIcon {
    if (isRejected) return Icons.cancel_rounded;
    if (isDisabled) return Icons.block_rounded;
    return Icons.hourglass_top_rounded;
  }

  String get _statusTitle {
    if (isRejected) return 'Registration Rejected';
    if (isDisabled) return 'Account Disabled';
    return 'Registration Submitted!';
  }

  String get _statusSubtitle {
    if (isRejected) {
      return isPendingContributor
          ? 'Your contributor registration has been rejected by the Admin.'
          : 'Your Admin application has been rejected by the Super Admin.';
    }
    if (isDisabled) {
      return 'Your account has been disabled. Please contact support.';
    }
    return isPendingContributor
        ? 'Your contributor account is awaiting Faculty Admin approval.'
        : 'Your Admin application is awaiting Super Admin approval.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = _statusColor;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E1E38)]
                : [const Color(0xFFF8FAFC), const Color(0xFFEEF2F6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Status icon
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(_statusIcon, size: 52, color: Colors.white),
                  ),
                  const SizedBox(height: 28),

                  Text(
                    _statusTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statusSubtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Rejection reason card
                  if (isRejected && rejectionReason != null && rejectionReason!.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.info_outline_rounded,
                                  size: 18, color: Color(0xFFEF4444)),
                              SizedBox(width: 8),
                              Text(
                                'Reason for Rejection',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEF4444),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            rejectionReason!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'You may re-register with the required corrections, or contact your department administrator.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              color: theme.disabledColor,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (isRejected && (rejectionReason == null || rejectionReason!.isEmpty))
                    const SizedBox.shrink(),

                  // Submitted details card (pending only, when details are known)
                  if (isPending && (name.isNotEmpty || email.isNotEmpty || department.isNotEmpty)) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: color.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  size: 18, color: color),
                              const SizedBox(width: 8),
                              Text(
                                'Submitted Details',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (name.isNotEmpty)
                            _detailRow(theme, Icons.person_outline_rounded, 'Name', name),
                          if (name.isNotEmpty) const SizedBox(height: 10),
                          if (email.isNotEmpty)
                            _detailRow(theme, Icons.email_outlined, 'Email', email),
                          if (email.isNotEmpty) const SizedBox(height: 10),
                          if (department.isNotEmpty)
                            _detailRow(theme, Icons.school_outlined, 'Department', department),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // What happens next (pending only)
                  if (isPending) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What happens next?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (isPendingContributor) ...[
                            _stepRow(theme, '1', 'The Faculty Admin for your department reviews your registration'),
                            const SizedBox(height: 8),
                            _stepRow(theme, '2', 'You\'ll receive an in-app notification upon approval or rejection'),
                            const SizedBox(height: 8),
                            _stepRow(theme, '3', 'Once approved, log in as Contributor and start uploading materials'),
                          ] else ...[
                            _stepRow(theme, '1', 'Super Admin reviews your application'),
                            const SizedBox(height: 8),
                            _stepRow(theme, '2', 'You\'ll be notified upon approval or rejection'),
                            const SizedBox(height: 8),
                            _stepRow(theme, '3', 'Once approved, log in as Admin'),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],

                  if (!isPending) const SizedBox(height: 36),

                  // Back to Login
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRejected ? const Color(0xFFEF4444) : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: Text(
                        isRejected ? 'Back to Login' : 'Back to Login',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
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

  Widget _detailRow(ThemeData theme, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.disabledColor),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                  color: theme.disabledColor,
                )),
            Text(value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                )),
          ],
        ),
      ],
    );
  }

  Widget _stepRow(ThemeData theme, String step, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(step,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                )),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.5)),
        ),
      ],
    );
  }
}
