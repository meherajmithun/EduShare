import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/role_helper.dart';
import 'package:edushare/core/providers/user_stats_provider.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/views/profile/edit_profile_screen.dart';
import 'package:edushare/views/settings/settings_screen.dart';
import 'package:edushare/views/bookmarks/saved_resources_screen.dart';
import 'package:edushare/views/course/watch_history_screen.dart';

/// profile_screen.dart — Figma-matched Student / Contributor / Admin Hub Profile Screen
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedDayIndex = DateTime.now().weekday - 1; // today by default

  @override
  void initState() {
    super.initState();
    // Only load learning stats for students
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthService>().currentUser;
      if (user?.role == 'student') {
        context.read<UserStatsProvider>().refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = context.select<AuthService, UserModel?>((s) => s.currentUser);
    final stats = context.watch<UserStatsProvider>();

    if (user == null) return const SizedBox.shrink();

    final photoUrl = user.profilePhotoUrl;

    // Role-aware hub label
    final hubLabel = () {
      switch (user.role) {
        case 'contributor':
          return 'CONTRIBUTOR HUB';
        case 'faculty_admin':
        case 'admin':
        case 'super_admin':
          return 'ADMIN HUB';
        default:
          return 'STUDENT HUB';
      }
    }();

    // ID display — prefer studentId or facultyId, fallback to uid prefix
    final idDisplay = () {
      if (user.studentId != null && user.studentId!.isNotEmpty) {
        return 'ID: ${user.studentId}';
      }
      if (user.facultyId != null && user.facultyId!.isNotEmpty) {
        return 'Faculty ID: ${user.facultyId}';
      }
      return 'ID: #${user.uid.substring(0, user.uid.length > 8 ? 8 : user.uid.length).toUpperCase()}';
    }();

    // Weekly chart data from provider (or empty fallback)
    final weeklyData = stats.weeklyActivity.isNotEmpty
        ? stats.weeklyActivity
        : [
            DayActivity(day: 'Mon', hours: 0),
            DayActivity(day: 'Tue', hours: 0),
            DayActivity(day: 'Wed', hours: 0),
            DayActivity(day: 'Thu', hours: 0),
            DayActivity(day: 'Fri', hours: 0),
            DayActivity(day: 'Sat', hours: 0),
            DayActivity(day: 'Sun', hours: 0),
          ];

    // Clamp selected day index
    final safeSelectedDay = _selectedDayIndex.clamp(0, weeklyData.length - 1);
    final maxHours = weeklyData.fold<double>(0, (m, e) => e.hours > m ? e.hours : m);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_back_rounded,
                      color: isDark ? Colors.white : AppTheme.lightTextPrimary, size: 18),
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Column(
          children: [
            Text(
              hubLabel,
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              'My Profile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.settings_outlined,
                  color: isDark ? Colors.white : AppTheme.lightTextPrimary, size: 18),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: () async {
          context.read<UserStatsProvider>().refresh(force: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero Profile Card ────────────────────────────────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isDark ? const Color(0xFF1E293B) : AppTheme.lightSurface,
                      AppTheme.primaryDark.withOpacity(isDark ? 0.8 : 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  children: [
                    // Avatar with verified badge
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                          ),
                          child: Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.primaryColor, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: (photoUrl != null && photoUrl.isNotEmpty)
                                  ? Image.network(
                                      photoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _buildAvatarFallback(user.name),
                                    )
                                  : _buildAvatarFallback(user.name),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Name
                    Text(
                      user.name,
                      style: TextStyle(
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // ID Tag (real studentId / facultyId)
                    Text(
                      idDisplay,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : AppTheme.lightTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Department & Semester Pills
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (user.department.isNotEmpty)
                          _InfoPill(
                            icon: Icons.school_outlined,
                            iconColor: AppTheme.primaryColor,
                            label: user.department,
                            isDark: isDark,
                          ),
                        if (user.semester != null)
                          _InfoPill(
                            icon: Icons.workspace_premium_outlined,
                            iconColor: const Color(0xFFF59E0B),
                            label: 'Semester ${user.semester}',
                            isDark: isDark,
                          ),
                        // Role pill
                        _InfoPill(
                          icon: Icons.badge_outlined,
                          iconColor: const Color(0xFF8B5CF6),
                          label: user.roleLabel,
                          isDark: isDark,
                        ),
                      ],
                    ),
                    // Bio (if set)
                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        user.bio!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withOpacity(0.6)
                              : AppTheme.lightTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Edit Profile Button
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: const Text('Edit Profile', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Learning Statistics (Students only) ─────────────────
              if (user.role == 'student') ...[
                const SizedBox(height: 24),
                Text(
                  'LEARNING STATISTICS',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              // 4 Grid Cards (real stats from UserStatsProvider)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.8,
                children: [
                  _StatCard(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    label: 'Completed',
                    value: stats.isLoading ? '...' : '${stats.completed}',
                    isDark: isDark,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WatchHistoryScreen()),
                    ),
                  ),
                  _StatCard(
                    icon: Icons.file_download_outlined,
                    iconColor: const Color(0xFF8B5CF6),
                    label: 'Engaged',
                    value: stats.isLoading ? '...' : '${stats.downloads}',
                    isDark: isDark,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WatchHistoryScreen()),
                    ),
                  ),
                  _StatCard(
                    icon: Icons.bookmark_border_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    label: 'Saved Notes',
                    value: stats.isLoading ? '...' : '${stats.savedNotes}',
                    isDark: isDark,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SavedResourcesScreen()),
                    ),
                  ),
                  _StatCard(
                    icon: Icons.timer_outlined,
                    iconColor: const Color(0xFF10B981),
                    label: 'Study Hours',
                    value: stats.isLoading
                        ? '...'
                        : '${stats.totalWeeklyHours.toStringAsFixed(1)} hrs',
                    isDark: isDark,
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Weekly Activity Chart ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Weekly Activity',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.lightTextPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            stats.isLoading
                                ? '...'
                                : '${stats.totalWeeklyHours.toStringAsFixed(1)} hrs',
                            style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Study hours over the last 7 days',
                      style: TextStyle(
                          color: isDark
                              ? Colors.white.withOpacity(0.5)
                              : AppTheme.lightTextSecondary,
                          fontSize: 11),
                    ),
                    const SizedBox(height: 20),
                    // 7-day bar chart
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(weeklyData.length, (index) {
                        final item = weeklyData[index];
                        final isSelected = index == safeSelectedDay;
                        // Normalise bar height relative to max hours (min 4px)
                        final double barHeight = maxHours > 0
                            ? (item.hours / maxHours) * 64 + 4
                            : 4;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedDayIndex = index),
                          child: Column(
                            children: [
                              if (isSelected)
                                Text(
                                  '${item.hours}h',
                                  style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold),
                                ),
                              const SizedBox(height: 2),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 24,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : (isDark
                                          ? Colors.white.withOpacity(0.15)
                                          : AppTheme.lightBorder),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color:
                                                AppTheme.primaryColor.withOpacity(0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : [],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.day,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : (isDark
                                          ? Colors.white.withOpacity(0.5)
                                          : AppTheme.lightTextSecondary),
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ), // weekly chart Container
              const SizedBox(height: 24),
              ], // end if (user.role == 'student')

              // ── Quick Actions ────────────────────────────────────────
              Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _QuickAction(
                icon: Icons.edit_rounded,
                label: 'Edit Profile',
                subtitle: 'Update name, bio, photo',
                isDark: isDark,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ),
              ),
              if (user.role == 'student') ...[
                const SizedBox(height: 10),
                _QuickAction(
                  icon: Icons.bookmark_rounded,
                  label: 'Saved Resources',
                  subtitle: '${stats.savedNotes} bookmarked items',
                  isDark: isDark,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SavedResourcesScreen()),
                  ),
                ),
                const SizedBox(height: 10),
                _QuickAction(
                  icon: Icons.history_rounded,
                  label: 'Watch History',
                  subtitle: '${stats.completed} completed videos',
                  isDark: isDark,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WatchHistoryScreen()),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _QuickAction(
                icon: Icons.settings_rounded,
                label: 'Settings',
                subtitle: 'Theme, security, account',
                isDark: isDark,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : 'S';
    return Container(
      color: AppTheme.primaryColor,
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isDark;

  const _InfoPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.1) : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? Colors.white24 : AppTheme.lightBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.lightTextPrimary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.5)
                          : AppTheme.lightTextSecondary,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary),
          ],
        ),
      ),
    );
  }
}
