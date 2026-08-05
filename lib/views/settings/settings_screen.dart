import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/providers/theme_provider.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/theme.dart';

/// Settings screen — Appearance / Theme + Account Security settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authService = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          Text(
            'Appearance',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.primaryColor,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          const _ThemeCard(),

          // ─── Account Security (only when biometrics are available) ────────
          if (authService.biometricsAvailable) ...[
            const SizedBox(height: 24),
            Text(
              'Account Security',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppTheme.primaryColor,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: authService.quickLoginEnabled
                            ? AppTheme.primaryColor.withOpacity(0.15)
                            : (isDark ? AppTheme.darkSurface : AppTheme.lightSurface),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.fingerprint_rounded,
                        size: 20,
                        color: authService.quickLoginEnabled
                            ? AppTheme.primaryColor
                            : theme.disabledColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Login',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Sign in with fingerprint or face ID',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                value: authService.quickLoginEnabled,
                activeColor: AppTheme.primaryColor,
                onChanged: (val) => authService.setQuickLoginEnabled(val),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkScheme = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDarkScheme ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkScheme ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'Theme',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDarkScheme
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
          ),
          const _ThemeOption(
            icon: Icons.wb_sunny_rounded,
            label: 'Light Mode',
            mode: ThemeMode.light,
            activeColor: Color(0xFFF59E0B),
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDarkScheme ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
          const _ThemeOption(
            icon: Icons.nightlight_round,
            label: 'Dark Mode',
            mode: ThemeMode.dark,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeMode mode;
  final Color activeColor;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.mode,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkScheme = theme.brightness == Brightness.dark;
    final isSelected =
        context.select<ThemeProvider, bool>((p) => p.themeMode == mode);

    return InkWell(
      onTap: () => context.read<ThemeProvider>().setTheme(mode),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withOpacity(0.15)
                    : (isDarkScheme
                        ? AppTheme.darkSurface
                        : AppTheme.lightSurface),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? activeColor : theme.disabledColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 15,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Container(
                      key: const ValueKey('check'),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    )
                  : const SizedBox(key: ValueKey('empty'), width: 22, height: 22),
            ),
          ],
        ),
      ),
    );
  }
}
