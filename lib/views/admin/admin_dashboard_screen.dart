import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/role_helper.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/widgets/notification_bell.dart';
import 'package:edushare/widgets/app_bar_profile_avatar.dart';
import 'package:edushare/views/admin/approvals_screen.dart';
import 'package:edushare/views/admin/all_materials_screen.dart';
import 'package:edushare/views/admin/users_screen.dart';
import 'package:edushare/views/admin/faculty_admins_screen.dart';

/// Admin Dashboard — stat cards showing totals, plus quick-action links.
/// Works for all admin-class roles (admin, faculty_admin, super_admin).
/// Faculty Admin stats are automatically scoped to their department by the API.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _service = FirestoreService();
  bool _isLoading = true;
  int _total = 0;
  int _pending = 0;
  int _approved = 0;
  int _rejected = 0;
  int _totalUsers = 0;
  int _pendingFacultyAdmins = 0; // Super Admin only

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload stats whenever this tab is revisited (live refresh)
    if (!_isLoading) _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final currentUser =
        Provider.of<AuthService>(context, listen: false).currentUser;

    try {
      if (currentUser != null && currentUser.isSuperAdmin) {
        // Super Admin: use dedicated stats endpoint
        final stats = await _service.getSuperAdminStats();
        final users = stats['users'] as Map<String, dynamic>? ?? {};
        final mats = stats['materials'] as Map<String, dynamic>? ?? {};
        if (mounted) {
          setState(() {
            _totalUsers = (users['total'] as num?)?.toInt() ?? 0;
            _pendingFacultyAdmins =
                (users['pendingFacultyAdmins'] as num?)?.toInt() ?? 0;
            _total = (mats['total'] as num?)?.toInt() ?? 0;
            _pending = (mats['pending'] as num?)?.toInt() ?? 0;
            _approved = (mats['approved'] as num?)?.toInt() ?? 0;
            _rejected = (mats['rejected'] as num?)?.toInt() ?? 0;
            _isLoading = false;
          });
        }
      } else {
        // Legacy admin / Faculty Admin: use /api/admin/stats (dept-scoped)
        final stats = await _service.getAdminStats();
        if (mounted) {
          setState(() {
            _totalUsers = (stats['totalUsers'] as num?)?.toInt() ?? 0;
            _total = (stats['totalMaterials'] as num?)?.toInt() ?? 0;
            final matPending = (stats['pendingCount'] as num?)?.toInt() ?? 0;
            _pendingFacultyAdmins = (stats['pendingContributors'] as num?)?.toInt() ?? 0;
            // Requirement 5: Combined Pending Reviews = Pending Materials + Pending Contributors
            _pending = matPending + _pendingFacultyAdmins;
            _approved = (stats['approvedCount'] as num?)?.toInt() ?? 0;
            _rejected = (stats['rejectedCount'] as num?)?.toInt() ?? 0;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser =
        context.select<AuthService, UserModel?>((s) => s.currentUser);

    final isSuperAdmin = currentUser?.isSuperAdmin ?? false;
    final isFacultyAdmin = currentUser?.isFacultyAdmin ?? false;
    final department = currentUser?.department ?? '';

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 180,
        leading: const AppBarProfileAvatar(),
        actions: const [NotificationBell()],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () async => _loadStats(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Welcome banner ──────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryColor, AppTheme.accentColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isSuperAdmin
                                ? Icons.shield_rounded
                                : isFacultyAdmin
                                    ? Icons.school_rounded
                                    : Icons.admin_panel_settings_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isSuperAdmin
                                ? 'Super Admin Control Panel'
                                : isFacultyAdmin
                                    ? 'Admin — $department'
                                    : 'Admin Control Panel',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isSuperAdmin
                                ? 'Manage Admins, users, and all academic content.'
                                : isFacultyAdmin
                                    ? 'Manage materials and users in your department.'
                                    : 'Manage uploads, users and academic content.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Pending approval request banner ────
                    if (_pendingFacultyAdmins > 0) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFF59E0B).withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.hourglass_top_rounded,
                                color: Color(0xFFF59E0B), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isSuperAdmin
                                    ? '$_pendingFacultyAdmins Faculty Admin registration${_pendingFacultyAdmins > 1 ? 's' : ''} awaiting your approval.'
                                    : '$_pendingFacultyAdmins Contributor registration${_pendingFacultyAdmins > 1 ? 's' : ''} awaiting your approval.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFFF59E0B),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Stats section title ─────────────────────────
                    Text(
                      'Overview',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),

                    // ── Stat grid ───────────────────────────────────
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _statCard(
                          context,
                          'Total Materials',
                          _total.toString(),
                          Icons.folder_rounded,
                          AppTheme.primaryColor,
                          isDark,
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(
                                builder: (_) => const AllMaterialsScreen(),
                              ))
                              .then((_) => _loadStats()),
                        ),
                        _statCard(
                          context,
                          'Pending Review',
                          _pending.toString(),
                          Icons.hourglass_top_rounded,
                          const Color(0xFFF59E0B),
                          isDark,
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(
                                builder: (_) => const ApprovalsScreen(),
                              ))
                              .then((_) => _loadStats()),
                        ),
                        _statCard(
                          context,
                          'Approved',
                          _approved.toString(),
                          Icons.check_circle_rounded,
                          const Color(0xFF10B981),
                          isDark,
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(
                                builder: (_) => const AllMaterialsScreen(),
                              ))
                              .then((_) => _loadStats()),
                        ),
                        _statCard(
                          context,
                          'Rejected',
                          _rejected.toString(),
                          Icons.cancel_rounded,
                          const Color(0xFFEF4444),
                          isDark,
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(
                                builder: (_) => const AllMaterialsScreen(),
                              ))
                              .then((_) => _loadStats()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Users stat card ─────────────────────────────
                    _wideStatCard(
                      context,
                      label: isFacultyAdmin
                          ? 'Users in Your Department'
                          : 'Total Active Users',
                      value: _totalUsers.toString(),
                      icon: Icons.people_rounded,
                      color: const Color(0xFF8B5CF6),
                      isDark: isDark,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(
                            builder: (_) => const UsersScreen(),
                          ))
                          .then((_) => _loadStats()),
                    ),
                    const SizedBox(height: 28),

                    // ── Quick Actions ───────────────────────────────
                    Text(
                      'Quick Actions',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),

                    if (isSuperAdmin && _pendingFacultyAdmins > 0)
                      _quickAction(
                        context,
                        icon: Icons.admin_panel_settings_rounded,
                        title: 'Review Admin Requests',
                        subtitle:
                            '$_pendingFacultyAdmins pending approval${_pendingFacultyAdmins > 1 ? 's' : ''}',
                        color: const Color(0xFFF59E0B),
                        isDark: isDark,
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(
                              builder: (_) => const FacultyAdminsScreen(),
                            ))
                            .then((_) => _loadStats()),
                      ),
                    if (isSuperAdmin && _pendingFacultyAdmins > 0)
                      const SizedBox(height: 10),

                    if (!isSuperAdmin && _pendingFacultyAdmins > 0)
                      _quickAction(
                        context,
                        icon: Icons.person_add_rounded,
                        title: 'Review Contributor Requests',
                        subtitle:
                            '$_pendingFacultyAdmins pending approval${_pendingFacultyAdmins > 1 ? 's' : ''}',
                        color: const Color(0xFFF59E0B),
                        isDark: isDark,
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(
                              builder: (_) => const ApprovalsScreen(),
                            ))
                            .then((_) => _loadStats()),
                      ),
                    if (!isSuperAdmin && _pendingFacultyAdmins > 0)
                      const SizedBox(height: 10),

                    _quickAction(
                      context,
                      icon: Icons.pending_actions_rounded,
                      title: 'Review Pending Uploads',
                      subtitle: '$_pending materials awaiting approval',
                      color: const Color(0xFFF59E0B),
                      isDark: isDark,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(
                            builder: (_) => const ApprovalsScreen(),
                          ))
                          .then((_) => _loadStats()),
                    ),
                    const SizedBox(height: 10),
                    _quickAction(
                      context,
                      icon: Icons.folder_copy_rounded,
                      title: 'All Materials',
                      subtitle: '$_total total resources',
                      color: AppTheme.primaryColor,
                      isDark: isDark,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(
                            builder: (_) => const AllMaterialsScreen(),
                          ))
                          .then((_) => _loadStats()),
                    ),
                    const SizedBox(height: 10),
                    _quickAction(
                      context,
                      icon: Icons.people_rounded,
                      title: isSuperAdmin ? 'Manage All Users' : 'Manage Users',
                      subtitle: '$_totalUsers active users',
                      color: const Color(0xFF8B5CF6),
                      isDark: isDark,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(
                            builder: (_) => const UsersScreen(),
                          ))
                          .then((_) => _loadStats()),
                    ),
                    if (isSuperAdmin) ...[
                      const SizedBox(height: 10),
                      _quickAction(
                        context,
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Manage Admins',
                        subtitle: 'View all Faculty Admins',
                        color: const Color(0xFFEF4444),
                        isDark: isDark,
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(
                              builder: (_) => const FacultyAdminsScreen(),
                            ))
                            .then((_) => _loadStats()),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value,
      IconData icon, Color color, bool isDark, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.displayLarge
                      ?.copyWith(fontSize: 28, color: color),
                ),
                Text(label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _wideStatCard(BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.displayLarge
                      ?.copyWith(fontSize: 32, color: color),
                ),
                Text(label,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.disabledColor),
          ],
        ),
      ),
    );
  }
}
