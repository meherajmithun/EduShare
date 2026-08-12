/// notifications_screen.dart — Activity Center matching Figma design.
///
/// Features:
///   - "ACTIVITY CENTER" label + "Notifications" title
///   - "Mark All Read" button (top-right)
///   - Notifications grouped by TODAY / YESTERDAY / EARLIER
///   - New-count badge on today's group header
///   - Rounded notification cards with type-specific colored icon circles
///   - Blue unread dot on unread notifications
///   - Tap to mark read + navigate to related entity
///   - Pull to refresh
///   - Empty state

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/notification_service.dart';
import 'package:edushare/models/notification_model.dart';
import 'package:edushare/widgets/glass_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationService>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final svc = context.watch<NotificationService>();
    final isDark = theme.brightness == Brightness.dark;

    // Group notifications
    final groups = _groupNotifications(svc.notifications);
    final todayUnread = (groups['today'] ?? []).where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              'ACTIVITY CENTER',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            Text(
              'Notifications',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          if (svc.notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                svc.markAllAsRead();
              },
              child: Text(
                'Mark All Read',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: svc.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : svc.notifications.isEmpty
              ? _buildEmpty(theme)
              : RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: () => svc.fetchNotifications(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if ((groups['today'] ?? []).isNotEmpty) ...[
                        _GroupHeader(
                          label: 'TODAY',
                          newCount: todayUnread,
                        ),
                        ...(groups['today']!).map(
                          (n) => _NotificationCard(
                            notification: n,
                            onTap: () => _handleTap(context, n, svc),
                          ),
                        ),
                      ],
                      if ((groups['yesterday'] ?? []).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const _GroupHeader(label: 'YESTERDAY'),
                        ...(groups['yesterday']!).map(
                          (n) => _NotificationCard(
                            notification: n,
                            onTap: () => _handleTap(context, n, svc),
                          ),
                        ),
                      ],
                      if ((groups['earlier'] ?? []).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const _GroupHeader(label: 'EARLIER'),
                        ...(groups['earlier']!).map(
                          (n) => _NotificationCard(
                            notification: n,
                            onTap: () => _handleTap(context, n, svc),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  void _handleTap(BuildContext context, NotificationModel n, NotificationService svc) {
    svc.markAsRead(n.id);
    // Navigation will be handled by the card's action button or tap area
    // Material navigation: go to material details if materialId present
    // For now, just mark as read (screens are already accessible from main nav)
  }

  Map<String, List<NotificationModel>> _groupNotifications(
      List<NotificationModel> all) {
    final now = DateTime.now();
    final today = <NotificationModel>[];
    final yesterday = <NotificationModel>[];
    final earlier = <NotificationModel>[];

    for (final n in all) {
      final diff = now.difference(n.createdAt);
      if (diff.inDays == 0 && now.day == n.createdAt.day) {
        today.add(n);
      } else if (diff.inDays <= 1 &&
          now.day - 1 == n.createdAt.day &&
          now.month == n.createdAt.month) {
        yesterday.add(n);
      } else {
        earlier.add(n);
      }
    }

    return {
      'today': today,
      'yesterday': yesterday,
      'earlier': earlier,
    };
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 36,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll be notified when\nsomething needs your attention.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Group Header ─────────────────────────────────────────────────────────────
class _GroupHeader extends StatelessWidget {
  final String label;
  final int newCount;

  const _GroupHeader({required this.label, this.newCount = 0});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: theme.disabledColor,
            ),
          ),
          if (newCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$newCount New',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Notification Card ────────────────────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  // ── Type metadata ────────────────────────────────────────────────────
  _TypeMeta get _meta {
    final n = notification;
    if (n.isApproval) {
      return _TypeMeta(
        label: 'APPROVAL NOTIFICATION',
        color: const Color(0xFF10B981),
        icon: Icons.check_circle_rounded,
        emoji: null,
      );
    }
    if (n.isRejection) {
      return _TypeMeta(
        label: 'REJECTION NOTIFICATION',
        color: const Color(0xFFEF4444),
        icon: Icons.cancel_rounded,
        emoji: null,
      );
    }
    if (n.isDownloadMilestone) {
      return _TypeMeta(
        label: 'DOWNLOAD MILESTONE',
        color: const Color(0xFFF59E0B),
        icon: null,
        emoji: '⭐',
      );
    }
    if (n.isNewFollower) {
      return _TypeMeta(
        label: 'NEW FOLLOWER',
        color: AppTheme.primaryColor,
        icon: Icons.person_add_rounded,
        emoji: null,
      );
    }
    if (n.isRating) {
      return _TypeMeta(
        label: 'RATING / REVIEW',
        color: const Color(0xFFF59E0B),
        icon: Icons.star_rounded,
        emoji: null,
      );
    }
    if (n.isPublished) {
      return _TypeMeta(
        label: 'NEW RESOURCE UPLOAD',
        color: const Color(0xFF8B5CF6),
        icon: Icons.upload_rounded,
        emoji: null,
      );
    }
    if (n.isAssignment) {
      return _TypeMeta(
        label: 'ASSIGNMENT REMINDER',
        color: const Color(0xFFEF4444),
        icon: Icons.access_time_rounded,
        emoji: null,
      );
    }
    if (n.isRegistration) {
      return _TypeMeta(
        label: 'CONTRIBUTOR APPROVAL',
        color: const Color(0xFF8B5CF6),
        icon: Icons.person_rounded,
        emoji: null,
      );
    }
    return _TypeMeta(
      label: 'NOTIFICATION',
      color: AppTheme.primaryColor,
      icon: Icons.notifications_rounded,
      emoji: null,
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _meta;
    final isUnread = !notification.isRead;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? meta.color.withOpacity(0.3)
                : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon circle
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: meta.color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: meta.emoji != null
                          ? Text(meta.emoji!, style: const TextStyle(fontSize: 20))
                          : Icon(meta.icon, color: meta.color, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type label + time
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                meta.label,
                                style: TextStyle(
                                  color: meta.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _timeAgo(notification.createdAt),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 10,
                                color: theme.disabledColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Title
                        Text(
                          notification.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Message
                        Text(
                          notification.message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Unread dot
                  if (isUnread)
                    Container(
                      margin: const EdgeInsets.only(left: 8, top: 2),
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              // Optional action button for material-linked notifications
              if (notification.hasMaterialLink) ...[
                const SizedBox(height: 10),
                _ActionButton(
                  label: notification.materialTitle != null
                      ? 'View Material ›'
                      : 'View Details ›',
                  color: meta.color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;

  const _ActionButton({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_ios_rounded, color: color, size: 10),
        ],
      ),
    );
  }
}

// ─── Type Metadata ────────────────────────────────────────────────────────────
class _TypeMeta {
  final String label;
  final Color color;
  final IconData? icon;
  final String? emoji;

  const _TypeMeta({
    required this.label,
    required this.color,
    this.icon,
    this.emoji,
  });
}
