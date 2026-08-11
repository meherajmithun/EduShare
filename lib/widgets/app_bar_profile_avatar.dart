/// app_bar_profile_avatar.dart
///
/// Reusable AppBar leading widget showing the logged-in user's profile picture
/// (or initials fallback) + name. Tapping navigates to ProfileScreen.
///
/// Usage (in any shell-level screen):
///   AppBar(
///     leadingWidth: 180,
///     leading: const AppBarProfileAvatar(),
///     actions: [const NotificationBell()],
///   )

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/views/profile/profile_screen.dart';

class AppBarProfileAvatar extends StatelessWidget {
  const AppBarProfileAvatar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthService, UserModel?>((s) => s.currentUser);
    if (user == null) return const SizedBox.shrink();

    final photoUrl = user.profilePhotoUrl;
    final name = user.name;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar circle
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: photoUrl == null || photoUrl.isEmpty
                    ? const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.accentColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                image: photoUrl != null && photoUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(photoUrl),
                        fit: BoxFit.cover,
                        onError: (_, __) {},
                      )
                    : null,
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            // Name — constrained so it never overflows
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                name.split(' ').first, // First name only to keep it compact
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
