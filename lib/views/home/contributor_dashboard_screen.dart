/// contributor_dashboard_screen.dart — Figma-matched Contributor Dashboard
///
/// Sections (top to bottom):
///   1. Header    — avatar + name + DASHBOARD/PRO badge + notification bell
///   2. Quick Upload — PDF Note | Video | Quiz/Test buttons
///   3. Key Performance — Total Uploads | Total Downloads | Avg Rating
///   4. Resource Status — Approved | Pending | Rejected + Manage All
///   5. Performance Analytics — Downloads/Views toggle + custom bar chart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/core/services/notification_service.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/widgets/glass_card.dart';
import 'package:edushare/views/upload/upload_resource_screen.dart';
import 'package:edushare/views/upload/my_uploads_screen.dart';
import 'package:edushare/views/notifications/notifications_screen.dart';
import 'package:edushare/views/profile/profile_screen.dart';

class ContributorDashboardScreen extends StatefulWidget {
  const ContributorDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ContributorDashboardScreen> createState() => _ContributorDashboardScreenState();
}

class _ContributorDashboardScreenState extends State<ContributorDashboardScreen> {
  final _service = FirestoreService();

  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String _analyticsMode = 'downloads'; // 'downloads' | 'views'

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _service.getContributorStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[ContributorDashboard] _loadStats error: $e\n$st');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Navigate to a screen and reload stats when it is popped.
  Future<void> _pushAndRefresh(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) _loadStats();
  }

  void _openUpload(String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UploadResourceScreen(
        initialType: type,
        onUploadSuccess: () {
          Navigator.of(context).pop();
          _loadStats();
        },
      ),
    ).then((_) {
      // Also refresh if the user dismissed without uploading but
      // came back from a state-changing sub-screen.
      if (mounted) _loadStats();
    });
  }

  List<dynamic> _getAnalyticsValues() {
    final key = _analyticsMode == 'downloads' ? 'monthlyDownloads' : 'monthlyViews';
    final raw = _stats?[key];
    if (raw is List) return raw;
    return <dynamic>[];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.select<AuthService, UserModel?>((s) => s.currentUser);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: _loadStats,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Header ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      // Avatar & Info — tappable → Profile Screen
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _pushAndRefresh(const ProfileScreen()),
                          child: Row(
                            children: [
                              _buildAvatar(user),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'CONTRIBUTOR DASHBOARD',
                                          style: theme.textTheme.labelLarge?.copyWith(
                                            color: AppTheme.darkTextSecondary,
                                            fontSize: 11,
                                            letterSpacing: 1.2,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user?.name ?? 'Contributor',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Top Right Action Buttons: Notification Bell & Profile Button
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _DashboardNotificationBell(),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _pushAndRefresh(const ProfileScreen()),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                color: AppTheme.primaryColor,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── Quick Upload ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'QUICK UPLOAD',
                            style: theme.textTheme.labelLarge?.copyWith(
                              letterSpacing: 1.2,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Select resource format',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 11,
                              color: theme.disabledColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // PDF Note — highlighted (primary)
                          Expanded(
                            child: _QuickUploadButton(
                              icon: Icons.description_rounded,
                              label: 'PDF Note',
                              isPrimary: true,
                              onTap: () => _openUpload('pdf'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Video
                          Expanded(
                            child: _QuickUploadButton(
                              icon: Icons.play_circle_fill_rounded,
                              label: 'Video',
                              onTap: () => _openUpload('video'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Quiz / Test
                          Expanded(
                            child: _QuickUploadButton(
                              icon: Icons.add_box_rounded,
                              label: 'Quiz / Test',
                              onTap: () => _openUpload('notes'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── Key Performance ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KEY PERFORMANCE',
                        style: theme.textTheme.labelLarge?.copyWith(
                          letterSpacing: 1.2,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isLoading)
                        _loadingCard(height: 100)
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _KeyStatCard(
                                label: 'Total Uploads',
                                value: '${_stats?['totalUploads'] ?? 0}',
                                subtitle: '+${_stats?['pendingUploads'] ?? 0} pending',
                                onTap: () => _pushAndRefresh(const MyUploadsScreen()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _KeyStatCard(
                                label: 'Total Views',
                                value: _formatCount(_stats?['totalViews'] ?? _stats?['totalDownloads'] ?? 0),
                                subtitle: 'total views',
                                onTap: () => _pushAndRefresh(const MyUploadsScreen()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _KeyStatCard(
                                label: 'Avg Rating',
                                value: (_stats?['avgRating'] as num? ?? 0.0).toStringAsFixed(1),
                                subtitle: '${_stats?['totalRatings'] ?? 0} reviews',
                                showStar: true,
                                onTap: () => _pushAndRefresh(const MyUploadsScreen()),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── Resource Status ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RESOURCE STATUS',
                            style: theme.textTheme.labelLarge?.copyWith(
                              letterSpacing: 1.2,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _pushAndRefresh(const MyUploadsScreen()),
                            child: Text(
                              'Manage All',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isLoading)
                        _loadingCard(height: 150)
                      else ...[
                        _StatusRow(
                          icon: Icons.check_circle_rounded,
                          color: const Color(0xFF10B981),
                          label: 'Approved Resources',
                          subtitle: 'Live & available for download',
                          count: _stats?['approvedUploads'] ?? 0,
                          onTap: () => _pushAndRefresh(
                            const MyUploadsScreen(initialFilter: 'approved'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _StatusRow(
                          icon: Icons.access_time_rounded,
                          color: const Color(0xFFF59E0B),
                          label: 'Pending Approval',
                          subtitle: 'Under review by moderator team',
                          count: _stats?['pendingUploads'] ?? 0,
                          onTap: () => _pushAndRefresh(
                            const MyUploadsScreen(initialFilter: 'pending'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _StatusRow(
                          icon: Icons.cancel_rounded,
                          color: const Color(0xFFEF4444),
                          label: 'Rejected Resources',
                          subtitle: 'Requires formatting or content fixes',
                          count: _stats?['rejectedUploads'] ?? 0,
                          onTap: () => _pushAndRefresh(
                            const MyUploadsScreen(initialFilter: 'rejected'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── Performance Analytics ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'PERFORMANCE ANALYTICS',
                            style: theme.textTheme.labelLarge?.copyWith(
                              letterSpacing: 1.2,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          // Toggle
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkSurface
                                  : AppTheme.lightCard,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                _ToggleTab(
                                  label: 'Downloads',
                                  isSelected: _analyticsMode == 'downloads',
                                  onTap: () => setState(() => _analyticsMode = 'downloads'),
                                ),
                                _ToggleTab(
                                  label: 'Views',
                                  isSelected: _analyticsMode == 'views',
                                  onTap: () => setState(() => _analyticsMode = 'views'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isLoading)
                        _loadingCard(height: 200)
                      else
                        _AnalyticsCard(
                          labels: (_stats?['monthlyLabels'] as List?)
                                  ?.map((e) => e.toString())
                                  .toList() ??
                              [],
                          values: _getAnalyticsValues(),
                        ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(UserModel? user) {
    final initials = user?.name.isNotEmpty == true
        ? user!.name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : 'C';

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        image: user?.profilePhotoUrl != null && user!.profilePhotoUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(user.profilePhotoUrl!),
                fit: BoxFit.cover,
                onError: (_, __) {},
              )
            : null,
      ),
      child: user?.profilePhotoUrl == null || user!.profilePhotoUrl!.isEmpty
          ? Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            )
          : null,
    );
  }

  Widget _loadingCard({required double height}) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: height,
        child: const Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryColor,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  static String _formatCount(dynamic count) {
    final n = (count as num?)?.toInt() ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─── Dashboard Notification Bell (opens Activity Center) ──────────────────────
class _DashboardNotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = context.select<NotificationService, int>((s) => s.unreadCount);
    return IconButton(
      tooltip: count > 0 ? '$count unread' : 'Notifications',
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        if (context.mounted) {
          context.read<NotificationService>().refreshUnreadCount();
        }
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),
          if (count > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


// ─── Quick Upload Button ──────────────────────────────────────────────────────
class _QuickUploadButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _QuickUploadButton({
    required this.icon,
    required this.label,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppTheme.primaryColor
              : (isDark ? AppTheme.darkSurface : AppTheme.lightCard),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPrimary
                ? AppTheme.primaryColor
                : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isPrimary ? Colors.white : AppTheme.primaryColor,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isPrimary
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Key Stat Card ────────────────────────────────────────────────────────────
class _KeyStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final bool showStar;
  final VoidCallback? onTap;

  const _KeyStatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    this.showStar = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget card = GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              if (showStar) ...[
                const SizedBox(width: 4),
                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}

// ─── Resource Status Row ──────────────────────────────────────────────────────
class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final int count;
  final VoidCallback? onTap;

  const _StatusRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Toggle Tab ───────────────────────────────────────────────────────────────
class _ToggleTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Analytics Card with bar chart ───────────────────────────────────────────
class _AnalyticsCard extends StatelessWidget {
  final List<String> labels;
  final List values;

  const _AnalyticsCard({
    required this.labels,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Convert values to doubles
    final doubles = values.map((v) => (v as num?)?.toDouble() ?? 0.0).toList();
    final maxVal = doubles.isEmpty
        ? 1.0
        : doubles.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    // Total for the period
    final total = doubles.fold<double>(0, (a, b) => a + b);

    // Build month range label
    String rangeLabel = '';
    if (labels.length >= 2) {
      rangeLabel = '${labels.first} – ${labels.last} ${DateTime.now().year}';
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Reach',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                rangeLabel,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _formatCount(total.toInt()),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Bar Chart
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(labels.length, (i) {
                final val = doubles.length > i ? doubles[i] : 0.0;
                final ratio = val / maxVal;
                final isLast = i == labels.length - 1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            height: (80 * ratio).clamp(4.0, 80.0),
                            decoration: BoxDecoration(
                              color: isLast
                                  ? AppTheme.primaryColor
                                  : (isDark
                                      ? const Color(0xFF3B4B5E)
                                      : const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          labels.length > i ? labels[i] : '',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.disabledColor,
                            fontWeight: isLast
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
