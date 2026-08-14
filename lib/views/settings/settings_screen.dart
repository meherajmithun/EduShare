import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edushare/core/providers/theme_provider.dart';
import 'package:edushare/core/providers/user_stats_provider.dart';
import 'package:edushare/core/role_helper.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/views/profile/edit_profile_screen.dart';

// ─── Colour tokens ────────────────────────────────────────────────────────────
const _kRed = Color(0xFFEF4444);
const _kAmber = Color(0xFFF59E0B);
const _kGreen = Color(0xFF10B981);
const _kPurple = Color(0xFF8B5CF6);
const _kCyan = Color(0xFF06B6D4);

/// Settings screen — User info header, Appearance, General Preferences,
/// Security & Privacy, Support & Info, Logout.
/// Matches the Figma design screenshot.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoggingOut = false;
  bool _notificationsEnabled = true;

  static const _notifKey = 'settings_notifications_enabled';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool(_notifKey) ?? true;
      });
    }
  }

  Future<void> _setNotifications(bool val) async {
    setState(() => _notificationsEnabled = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifKey, val);
  }

  Future<void> _confirmLogout() async {
    final user =
        Provider.of<AuthService>(context, listen: false).currentUser;
    final isAdminRole = user != null &&
        (user.isSuperAdmin || user.isFacultyAdmin || user.role == 'admin');
    final label = isAdminRole ? 'Log Out Admin Session' : 'Sign Out';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkSurface
            : AppTheme.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out of EduShare?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(label),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoggingOut = true);
      context.read<UserStatsProvider>().reset();
      await context.read<AuthService>().signOut();
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$feature — Coming soon'),
      backgroundColor: AppTheme.primaryColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _launchSupport() async {
    final uri = Uri.parse('mailto:support@edushare.app?subject=Help%20Request');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showComingSoon('Help & Support Desk');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    final isAdminRole = user != null &&
        (user.isSuperAdmin || user.isFacultyAdmin || user.role == 'admin');
    final logoutLabel =
        isAdminRole ? 'Log Out Admin Session' : 'Sign Out';

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings',
            style:
                theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [

          // ── User Info Header Card ───────────────────────────────────────
          if (user != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor
                        .withValues(alpha: isDark ? 0.25 : 0.08),
                    AppTheme.accentColor
                        .withValues(alpha: isDark ? 0.1 : 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  _MiniAvatar(user: user),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(user.email,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontSize: 12)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(user.roleLabel,
                              style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded,
                        color: AppTheme.primaryColor, size: 20),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const EditProfileScreen())),
                    tooltip: 'Edit Profile',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
          ],

          // ── Appearance ─────────────────────────────────────────────────
          _sectionLabel(context, 'APPEARANCE'),
          const SizedBox(height: 10),
          const _ThemeCard(),
          const SizedBox(height: 26),

          // ── General Preferences ────────────────────────────────────────
          _sectionLabel(context, 'GENERAL PREFERENCES'),
          const SizedBox(height: 10),
          _SettingsCard(
            isDark: isDark,
            children: [
              // Notifications toggle
              _SwitchRow(
                icon: Icons.notifications_outlined,
                iconColor: AppTheme.primaryColor,
                label: 'Notifications',
                subtitle: 'Push and in-app alerts',
                isDark: isDark,
                value: _notificationsEnabled,
                onChanged: _setNotifications,
              ),
              _cardDivider(isDark),
              // Language
              _ArrowRow(
                icon: Icons.language_outlined,
                iconColor: _kCyan,
                label: 'Language',
                trailing: Text('English (US)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary)),
                isDark: isDark,
                onTap: () => _showComingSoon('Language'),
              ),
            ],
          ),
          const SizedBox(height: 26),

          // ── Account Security ───────────────────────────────────────────
          _sectionLabel(context, 'SECURITY & PRIVACY'),
          const SizedBox(height: 10),
          _SettingsCard(
            isDark: isDark,
            children: [
              // Quick Login (biometric) — show if available
              if (authService.biometricsAvailable) ...[
                _SwitchRow(
                  icon: Icons.fingerprint_rounded,
                  iconColor: AppTheme.primaryColor,
                  label: 'Quick Login',
                  subtitle: 'Sign in with fingerprint or Face ID',
                  isDark: isDark,
                  value: authService.quickLoginEnabled,
                  onChanged: (val) => authService.setQuickLoginEnabled(val),
                ),
                _cardDivider(isDark),
              ],
              // 2FA
              _ArrowRow(
                icon: Icons.shield_outlined,
                iconColor: _kGreen,
                label: 'Security',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('2FA ON',
                      style: TextStyle(
                          color: _kGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
                isDark: isDark,
                onTap: () => _showComingSoon('2FA Security'),
              ),
              _cardDivider(isDark),
              // Privacy
              _ArrowRow(
                icon: Icons.lock_outline_rounded,
                iconColor: _kPurple,
                label: 'Privacy',
                isDark: isDark,
                onTap: () => _showComingSoon('Privacy Settings'),
              ),
            ],
          ),
          const SizedBox(height: 26),

          // ── Account ────────────────────────────────────────────────────
          _sectionLabel(context, 'ACCOUNT'),
          const SizedBox(height: 10),
          _SettingsCard(
            isDark: isDark,
            children: [
              _ArrowRow(
                icon: Icons.person_outline_rounded,
                iconColor: AppTheme.primaryColor,
                label: 'Edit Profile',
                subtitle: 'Update name, bio, photo',
                isDark: isDark,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const EditProfileScreen())),
              ),
            ],
          ),
          const SizedBox(height: 26),

          // ── Support & Info ─────────────────────────────────────────────
          _sectionLabel(context, 'SUPPORT & INFO'),
          const SizedBox(height: 10),
          _SettingsCard(
            isDark: isDark,
            children: [
              _ArrowRow(
                icon: Icons.support_agent_outlined,
                iconColor: _kCyan,
                label: 'Help & Support Desk',
                subtitle: 'Contact the EduShare team',
                isDark: isDark,
                onTap: _launchSupport,
              ),
              _cardDivider(isDark),
              _ArrowRow(
                icon: Icons.info_outline_rounded,
                iconColor: _kAmber,
                label: 'About System',
                trailing: Text('v2.4.0 (Build 2026.07)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary)),
                isDark: isDark,
                onTap: () => _showAboutDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Logout Button ──────────────────────────────────────────────
          _isLoggingOut
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : GestureDetector(
                  onTap: _confirmLogout,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kRed, Color(0xFFDC2626)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          logoutLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppTheme.primaryColor,
            letterSpacing: 0.8,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _cardDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school_rounded,
                  color: AppTheme.primaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('EduShare',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version 2.4.0 (Build 2026.07)'),
            SizedBox(height: 8),
            Text(
                'EduShare is an academic resource sharing platform for university students and faculty.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ─── Mini Avatar ─────────────────────────────────────────────────────────────

class _MiniAvatar extends StatelessWidget {
  final UserModel user;
  const _MiniAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.profilePhotoUrl;
    final name = user.name;
    final initials = name.isNotEmpty
        ? name
            .trim()
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: (photoUrl == null || photoUrl.isEmpty)
            ? const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : null,
        image: (photoUrl != null && photoUrl.isNotEmpty)
            ? DecorationImage(
                image: NetworkImage(photoUrl),
                fit: BoxFit.cover,
                onError: (_, __) {})
            : null,
        border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.5), width: 2),
      ),
      child: (photoUrl == null || photoUrl.isEmpty)
          ? Center(
              child: Text(initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)))
          : null,
    );
  }
}

// ─── Theme Card ───────────────────────────────────────────────────────────────

class _ThemeCard extends StatelessWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _SettingsCard(
      isDark: isDark,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text('Theme',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  )),
        ),
        // 3 pill options in one row
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
          child: Row(
            children: const [
              Expanded(
                child: _ThemePill(
                  icon: Icons.wb_sunny_rounded,
                  label: 'Light',
                  mode: ThemeMode.light,
                  activeColor: _kAmber,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ThemePill(
                  icon: Icons.nightlight_round,
                  label: 'Dark',
                  mode: ThemeMode.dark,
                  activeColor: AppTheme.primaryColor,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ThemePill(
                  icon: Icons.phone_android_rounded,
                  label: 'System',
                  mode: ThemeMode.system,
                  activeColor: _kPurple,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeMode mode;
  final Color activeColor;

  const _ThemePill({
    required this.icon,
    required this.label,
    required this.mode,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected =
        context.select<ThemeProvider, bool>((p) => p.themeMode == mode);

    return GestureDetector(
      onTap: () => context.read<ThemeProvider>().setTheme(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : (isDark ? AppTheme.darkSurface : AppTheme.lightSurface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected
                  ? activeColor
                  : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              width: isSelected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 20,
                color: isSelected ? activeColor : Theme.of(context).disabledColor),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? activeColor
                        : (isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary))),
          ],
        ),
      ),
    );
  }
}

// ─── Settings Card container ──────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;

  const _SettingsCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ─── Switch Row ───────────────────────────────────────────────────────────────

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final bool isDark;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isDark,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      contentPadding: const EdgeInsets.fromLTRB(14, 4, 12, 4),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: value
                  ? iconColor.withValues(alpha: 0.15)
                  : (isDark ? AppTheme.darkSurface : AppTheme.lightSurface),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon,
                size: 18, color: value ? iconColor : theme.disabledColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle!,
                      style:
                          theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
      value: value,
      activeThumbColor: iconColor,
      onChanged: onChanged,
    );
  }
}

// ─── Arrow Row (non-toggle rows) ──────────────────────────────────────────────

class _ArrowRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final bool isDark;
  final VoidCallback? onTap;

  const _ArrowRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isDark,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style:
                            theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
                ],
              ),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
            if (onTap != null)
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary),
          ],
        ),
      ),
    );
  }
}
