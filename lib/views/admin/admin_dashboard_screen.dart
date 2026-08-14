import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/role_helper.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/widgets/notification_bell.dart';
import 'package:edushare/widgets/app_bar_profile_avatar.dart';
import 'package:edushare/views/admin/approvals_screen.dart';
import 'package:edushare/views/admin/all_materials_screen.dart';
import 'package:edushare/views/admin/users_screen.dart';
import 'package:edushare/views/admin/faculty_admins_screen.dart';
import 'package:edushare/views/admin/manage_courses_screen.dart';
import 'package:edushare/views/profile/profile_screen.dart';

// ─── Colour tokens (matching Figma dark palette) ─────────────────────────────
const _kAmber = Color(0xFFF59E0B);
const _kGreen = Color(0xFF10B981);
const _kRed = Color(0xFFEF4444);
const _kPurple = Color(0xFF8B5CF6);
const _kCyan = Color(0xFF06B6D4);
const _kIndigoLight = Color(0xFF818CF8);

/// Admin Dashboard — stat cards showing totals, plus quick-action links.
/// For Super Admin this renders the Figma-matched dashboard layout.
/// For Faculty Admin / legacy Admin the previous layout is preserved.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _service = FirestoreService();
  bool _isLoading = true;

  // ── Super Admin stats ──────────────────────────────────────────────
  int _totalStudents = 0;
  int _totalContributors = 0;
  int _totalAdmins = 0;
  int _pendingAdmins = 0;
  int _pendingMaterials = 0;
  int _approvedMaterials = 0;
  int _rejectedMaterials = 0;

  // ── Legacy admin stats ─────────────────────────────────────────────
  int _total = 0;
  int _pending = 0;
  int _approved = 0;
  int _rejected = 0;
  int _totalUsers = 0;
  int _pendingFacultyAdmins = 0;

  // ── Pending materials queue (Super Admin dashboard list) ───────────
  List<MaterialModel> _pendingQueue = [];
  bool _queueLoading = true;

  // ── Recent activity (recent users) ────────────────────────────────
  List<UserModel> _recentUsers = [];
  bool _activityLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isLoading) _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final currentUser =
        Provider.of<AuthService>(context, listen: false).currentUser;

    try {
      if (currentUser != null && currentUser.isSuperAdmin) {
        final stats = await _service.getSuperAdminStats();
        final users = stats['users'] as Map<String, dynamic>? ?? {};
        final mats = stats['materials'] as Map<String, dynamic>? ?? {};
        if (mounted) {
          setState(() {
            _totalStudents = (users['totalStudents'] as num?)?.toInt() ?? 0;
            _totalContributors =
                (users['totalContributors'] as num?)?.toInt() ?? 0;
            _totalAdmins = (users['totalAdmins'] as num?)?.toInt() ?? 0;
            _pendingAdmins = (users['pendingAdmins'] as num?)?.toInt() ?? 0;
            _pendingMaterials = (mats['pending'] as num?)?.toInt() ?? 0;
            _approvedMaterials = (mats['approved'] as num?)?.toInt() ?? 0;
            _rejectedMaterials = (mats['rejected'] as num?)?.toInt() ?? 0;
            _isLoading = false;
          });
        }
        _loadSuperAdminDetails();
      } else {
        final stats = await _service.getAdminStats();
        if (mounted) {
          setState(() {
            _totalUsers = (stats['totalUsers'] as num?)?.toInt() ?? 0;
            _total = (stats['totalMaterials'] as num?)?.toInt() ?? 0;
            final matPending = (stats['pendingCount'] as num?)?.toInt() ?? 0;
            _pendingFacultyAdmins =
                (stats['pendingContributors'] as num?)?.toInt() ?? 0;
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

  Future<void> _loadSuperAdminDetails() async {
    try {
      final mats = await _service.getAllMaterials(status: 'pending');
      if (mounted) {
        setState(() {
          _pendingQueue = mats.take(5).toList();
          _queueLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _queueLoading = false);
    }

    try {
      final users = await _service.getAllUsers();
      if (mounted) {
        final sorted = [...users]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        setState(() {
          _recentUsers = sorted.take(5).toList();
          _activityLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _activityLoading = false);
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    if (isSuperAdmin) {
      return _SuperAdminDashboard(
        currentUser: currentUser,
        isDark: isDark,
        totalStudents: _totalStudents,
        totalContributors: _totalContributors,
        totalAdmins: _totalAdmins,
        pendingAdmins: _pendingAdmins,
        pendingMaterials: _pendingMaterials,
        approvedMaterials: _approvedMaterials,
        rejectedMaterials: _rejectedMaterials,
        pendingQueue: _pendingQueue,
        queueLoading: _queueLoading,
        recentUsers: _recentUsers,
        activityLoading: _activityLoading,
        onRefresh: _loadStats,
        service: _service,
      );
    }

    // ── Legacy Admin / Faculty Admin layout ────────────────────────────────
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 180,
        leading: const AppBarProfileAvatar(),
        actions: const [NotificationBell()],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: () async => _loadStats(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      isFacultyAdmin
                          ? Icons.school_rounded
                          : Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isFacultyAdmin ? 'Admin — $department' : 'Admin Control Panel',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFacultyAdmin
                          ? 'Manage materials and users in your department.'
                          : 'Manage uploads, users and academic content.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_pendingFacultyAdmins > 0) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kAmber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kAmber.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top_rounded,
                          color: _kAmber, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$_pendingFacultyAdmins Contributor registration${_pendingFacultyAdmins > 1 ? 's' : ''} awaiting your approval.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: _kAmber,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text('Overview',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _legacyStatCard(context, 'Total Materials', _total.toString(),
                      Icons.folder_rounded, AppTheme.primaryColor, isDark,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (_) => const AllMaterialsScreen()))
                          .then((_) => _loadStats())),
                  _legacyStatCard(context, 'Pending Review', _pending.toString(),
                      Icons.hourglass_top_rounded, _kAmber, isDark,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (_) => const ApprovalsScreen()))
                          .then((_) => _loadStats())),
                  _legacyStatCard(context, 'Approved', _approved.toString(),
                      Icons.check_circle_rounded, _kGreen, isDark,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (_) => const AllMaterialsScreen()))
                          .then((_) => _loadStats())),
                  _legacyStatCard(context, 'Rejected', _rejected.toString(),
                      Icons.cancel_rounded, _kRed, isDark,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (_) => const AllMaterialsScreen()))
                          .then((_) => _loadStats())),
                ],
              ),
              const SizedBox(height: 16),
              _legacyWideStatCard(context,
                  label: isFacultyAdmin
                      ? 'Users in Your Department'
                      : 'Total Active Users',
                  value: _totalUsers.toString(),
                  icon: Icons.people_rounded,
                  color: _kPurple,
                  isDark: isDark,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(
                          builder: (_) => const UsersScreen()))
                      .then((_) => _loadStats())),
              const SizedBox(height: 28),
              Text('Quick Actions',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              if (_pendingFacultyAdmins > 0) ...[
                _legacyQuickAction(context,
                    icon: Icons.person_add_rounded,
                    title: 'Review Contributor Requests',
                    subtitle:
                        '$_pendingFacultyAdmins pending approval${_pendingFacultyAdmins > 1 ? 's' : ''}',
                    color: _kAmber,
                    isDark: isDark,
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (_) => const ApprovalsScreen()))
                        .then((_) => _loadStats())),
                const SizedBox(height: 10),
              ],
              _legacyQuickAction(context,
                  icon: Icons.pending_actions_rounded,
                  title: 'Review Pending Uploads',
                  subtitle: '$_pending materials awaiting approval',
                  color: _kAmber,
                  isDark: isDark,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(
                          builder: (_) => const ApprovalsScreen()))
                      .then((_) => _loadStats())),
              const SizedBox(height: 10),
              _legacyQuickAction(context,
                  icon: Icons.folder_copy_rounded,
                  title: 'All Materials',
                  subtitle: '$_total total resources',
                  color: AppTheme.primaryColor,
                  isDark: isDark,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(
                          builder: (_) => const AllMaterialsScreen()))
                      .then((_) => _loadStats())),
              const SizedBox(height: 10),
              _legacyQuickAction(context,
                  icon: Icons.people_rounded,
                  title: 'Manage Users',
                  subtitle: '$_totalUsers active users',
                  color: _kPurple,
                  isDark: isDark,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(
                          builder: (_) => const UsersScreen()))
                      .then((_) => _loadStats())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legacyStatCard(BuildContext context, String label, String value,
      IconData icon, Color color, bool isDark, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: theme.textTheme.displayLarge
                        ?.copyWith(fontSize: 28, color: color)),
                Text(label,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legacyWideStatCard(BuildContext context,
      {required String label, required String value, required IconData icon,
       required Color color, required bool isDark, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: theme.textTheme.displayLarge
                        ?.copyWith(fontSize: 32, color: color)),
                Text(label,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legacyQuickAction(BuildContext context,
      {required IconData icon, required String title, required String subtitle,
       required Color color, required bool isDark, required VoidCallback onTap}) {
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
                color: color.withValues(alpha: 0.1),
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
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
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

// ═══════════════════════════════════════════════════════════════════════════════
// Super Admin Dashboard Widget
// ═══════════════════════════════════════════════════════════════════════════════

class _SuperAdminDashboard extends StatelessWidget {
  final UserModel? currentUser;
  final bool isDark;
  final int totalStudents;
  final int totalContributors;
  final int totalAdmins;
  final int pendingAdmins;
  final int pendingMaterials;
  final int approvedMaterials;
  final int rejectedMaterials;
  final List<MaterialModel> pendingQueue;
  final bool queueLoading;
  final List<UserModel> recentUsers;
  final bool activityLoading;
  final VoidCallback onRefresh;
  final FirestoreService service;

  const _SuperAdminDashboard({
    required this.currentUser,
    required this.isDark,
    required this.totalStudents,
    required this.totalContributors,
    required this.totalAdmins,
    required this.pendingAdmins,
    required this.pendingMaterials,
    required this.approvedMaterials,
    required this.rejectedMaterials,
    required this.pendingQueue,
    required this.queueLoading,
    required this.recentUsers,
    required this.activityLoading,
    required this.onRefresh,
    required this.service,
  });

  Color get _cardBg => isDark ? AppTheme.darkCard : AppTheme.lightCard;
  Color get _borderColor => isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = currentUser?.name ?? 'Super Admin';
    final photoUrl = currentUser?.profilePhotoUrl;
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : 'SA';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: () async => onRefresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Profile Top Bar ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: photoUrl == null || photoUrl.isEmpty
                                      ? const LinearGradient(
                                          colors: [AppTheme.primaryColor, AppTheme.accentColor],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight)
                                      : null,
                                  image: photoUrl != null && photoUrl.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(photoUrl),
                                          fit: BoxFit.cover,
                                          onError: (_, __) {})
                                      : null,
                                  border: Border.all(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.5), width: 2),
                                ),
                                child: photoUrl == null || photoUrl.isEmpty
                                    ? Center(
                                        child: Text(initials,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)))
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(name,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold, fontSize: 16)),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                                color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                                          ),
                                          child: const Text('SUPER ADMIN',
                                              style: TextStyle(
                                                  color: _kIndigoLight,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5)),
                                        ),
                                      ],
                                    ),
                                    Text('Platform Overview & Management',
                                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const NotificationBell(),
                    ],
                  ),
                ),
              ),

              // ── Pending Admin Banner ─────────────────────────────────
              if (pendingAdmins > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FacultyAdminsScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _kAmber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kAmber.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.hourglass_top_rounded, color: _kAmber, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$pendingAdmins Admin registration${pendingAdmins > 1 ? 's' : ''} awaiting your approval',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color: _kAmber, fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: _kAmber, size: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Quick Actions ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel(context, 'QUICK ACTIONS'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _QuickActionTile(
                            icon: Icons.pending_actions_rounded,
                            label: 'Review\nPending',
                            color: _kAmber,
                            isDark: isDark,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ApprovalsScreen())),
                          ),
                          const SizedBox(width: 10),
                          _QuickActionTile(
                            icon: Icons.add_circle_outline_rounded,
                            label: 'Add\nCourse',
                            color: AppTheme.primaryColor,
                            isDark: isDark,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ManageCoursesScreen())),
                          ),
                          const SizedBox(width: 10),
                          _QuickActionTile(
                            icon: Icons.receipt_long_rounded,
                            label: 'Audit\nLog',
                            color: _kCyan,
                            isDark: isDark,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const UsersScreen())),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Platform Statistics ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionLabel(context, 'PLATFORM STATISTICS'),
                          Text('Live Data',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _kGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Total Students',
                              value: _fmtNum(totalStudents),
                              trend: 'All Active',
                              trendColor: _kGreen,
                              icon: Icons.school_rounded,
                              iconColor: _kCyan,
                              isDark: isDark,
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const UsersScreen())),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Contributors',
                              value: _fmtNum(totalContributors),
                              trend: 'Active',
                              trendColor: _kGreen,
                              icon: Icons.people_alt_rounded,
                              iconColor: _kPurple,
                              isDark: isDark,
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const UsersScreen())),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Active Admins',
                              value: _fmtNum(totalAdmins),
                              trend: pendingAdmins > 0
                                  ? '$pendingAdmins Pending'
                                  : 'All Active',
                              trendColor: pendingAdmins > 0 ? _kAmber : _kGreen,
                              icon: Icons.menu_book_rounded,
                              iconColor: _kGreen,
                              isDark: isDark,
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const FacultyAdminsScreen())),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PendingReviewCard(
                              count: pendingMaterials,
                              isDark: isDark,
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const ApprovalsScreen())),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Upload Trend Chart ───────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _borderColor),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Resource Upload Trend',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Monthly uploads vs moderation rate',
                                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
                              ],
                            ),
                            Row(
                              children: const [
                                _ChartLegend(color: _kIndigoLight, label: 'Uploads'),
                                SizedBox(width: 12),
                                _ChartLegend(color: _kGreen, label: 'Approved'),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 140,
                          child: _UploadTrendChart(
                            totalUploads: approvedMaterials + pendingMaterials + rejectedMaterials,
                            approved: approvedMaterials,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Pending Queue ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionLabel(context, 'PENDING QUEUE ($pendingMaterials)'),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ApprovalsScreen())),
                        child: const Text('View All Queue',
                            style: TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),

              if (queueLoading)
                const SliverToBoxAdapter(
                  child: Center(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryColor, strokeWidth: 2))),
                )
              else if (pendingQueue.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: _EmptyCard(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'No pending materials',
                        isDark: isDark),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: _PendingQueueCard(
                        material: pendingQueue[i],
                        isDark: isDark,
                        service: service,
                        onAction: onRefresh,
                      ),
                    ),
                    childCount: pendingQueue.length,
                  ),
                ),

              // ── Recent Activity ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _sectionLabel(context, 'RECENT SYSTEM ACTIVITY'),
                ),
              ),

              if (activityLoading)
                const SliverToBoxAdapter(
                  child: Center(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryColor, strokeWidth: 2))),
                )
              else if (recentUsers.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: _EmptyCard(
                        icon: Icons.history_rounded,
                        label: 'No recent activity',
                        isDark: isDark),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                      ),
                      child: Column(
                        children: recentUsers.asMap().entries.map((e) => _ActivityRow(
                              user: e.value,
                              isDark: isDark,
                              isLast: e.key == recentUsers.length - 1,
                            )).toList(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 11,
            letterSpacing: 0.8,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
    );
  }
}

// ─── Quick Action Tile ────────────────────────────────────────────────────────

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String trend;
  final Color trendColor;
  final IconData icon;
  final Color iconColor;
  final bool isDark;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.trendColor,
    required this.icon,
    required this.iconColor,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(trend,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: trendColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── Pending Review Highlighted Card ─────────────────────────────────────────

class _PendingReviewCard extends StatelessWidget {
  final int count;
  final bool isDark;
  final VoidCallback? onTap;

  const _PendingReviewCard(
      {required this.count, required this.isDark, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kAmber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kAmber.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pending Review',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontSize: 11, color: _kAmber)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kAmber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(count.toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('$count Files',
                style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 22, fontWeight: FontWeight.bold, color: _kAmber)),
            const SizedBox(height: 4),
            Text('Action Required',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: _kAmber, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── Upload Trend Line Chart ──────────────────────────────────────────────────

class _UploadTrendChart extends StatelessWidget {
  final int totalUploads;
  final int approved;

  const _UploadTrendChart({required this.totalUploads, required this.approved});

  @override
  Widget build(BuildContext context) {
    final base = totalUploads.toDouble().clamp(1.0, double.infinity);
    final appBase = approved.toDouble().clamp(0.0, base);
    final factors = [0.4, 0.55, 0.7, 0.85, 1.0];

    final uploadsSpots = factors.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), (base * e.value).roundToDouble()))
        .toList();
    final approvedSpots = factors.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), (appBase * e.value).roundToDouble()))
        .toList();
    final labels = ['Mar', 'Apr', 'May', 'Jun', 'Jul'];

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= labels.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labels[idx],
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.darkTextSecondary)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.darkSurface,
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: uploadsSpots,
            isCurved: true,
            color: _kIndigoLight,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
                show: true, color: _kIndigoLight.withValues(alpha: 0.08)),
          ),
          LineChartBarData(
            spots: approvedSpots,
            isCurved: true,
            color: _kGreen,
            barWidth: 2.5,
            dashArray: [6, 4],
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
                show: true, color: _kGreen.withValues(alpha: 0.06)),
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── Pending Queue Card ───────────────────────────────────────────────────────

class _PendingQueueCard extends StatefulWidget {
  final MaterialModel material;
  final bool isDark;
  final FirestoreService service;
  final VoidCallback onAction;

  const _PendingQueueCard({
    required this.material,
    required this.isDark,
    required this.service,
    required this.onAction,
  });

  @override
  State<_PendingQueueCard> createState() => _PendingQueueCardState();
}

class _PendingQueueCardState extends State<_PendingQueueCard> {
  bool _processing = false;

  Color get _typeColor {
    switch (widget.material.type) {
      case 'video': return _kRed;
      case 'pdf': return _kPurple;
      case 'notes': return _kCyan;
      default: return _kGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mat = widget.material;
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: widget.isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(mat.type.toUpperCase(),
                    style: TextStyle(
                        color: _typeColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(mat.title,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Needs Review',
                    style: TextStyle(
                        color: _kAmber, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Uploaded by ${mat.contributorName} • ${mat.department.isNotEmpty ? mat.department : 'General'}',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
          const SizedBox(height: 12),
          _processing
              ? const Center(
                  child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryColor, strokeWidth: 2)))
              : Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _approve(context),
                        child: Container(
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: _kGreen, width: 1.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Approve & Publish',
                              style: TextStyle(
                                  color: _kGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _reject(context),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: _kRed, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Reject',
                            style: TextStyle(
                                color: _kRed,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context) async {
    setState(() => _processing = true);
    try {
      await widget.service.updateMaterialStatus(widget.material.id, 'approved');
      widget.onAction();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: _kRed,
            behavior: SnackBarBehavior.floating));
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _reject(BuildContext context) async {
    setState(() => _processing = true);
    try {
      await widget.service.updateMaterialStatus(widget.material.id, 'rejected');
      widget.onAction();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: _kRed,
            behavior: SnackBarBehavior.floating));
        setState(() => _processing = false);
      }
    }
  }
}

// ─── Activity Row ─────────────────────────────────────────────────────────────

class _ActivityRow extends StatelessWidget {
  final UserModel user;
  final bool isDark;
  final bool isLast;

  const _ActivityRow(
      {required this.user, required this.isDark, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color dotColor;
    String action;
    switch (user.role) {
      case 'contributor':
        dotColor = _kCyan;
        action = '${user.name} registered as Contributor';
        break;
      case 'faculty_admin':
      case 'admin':
        dotColor = _kAmber;
        action = '${user.name} registered as Admin';
        break;
      default:
        dotColor = _kGreen;
        action = '${user.name} joined as Student';
    }

    final diff = DateTime.now().difference(user.createdAt);
    final timeAgo = diff.inMinutes < 60
        ? '${diff.inMinutes}m ago'
        : diff.inHours < 24
            ? '${diff.inHours}h ago'
            : '${diff.inDays}d ago';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(action,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
              ),
              Text(timeAgo,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10)),
            ],
          ),
        ),
        if (!isLast)
          Divider(
              height: 1,
              indent: 32,
              endIndent: 14,
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ],
    );
  }
}

// ─── Empty Card ───────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  const _EmptyCard({required this.icon, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor.withValues(alpha: 0.4), size: 36),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

String _fmtNum(int n) =>
    n >= 1000 ? NumberFormat('#,###').format(n) : n.toString();
