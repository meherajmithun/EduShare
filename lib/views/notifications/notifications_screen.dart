import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/notification_service.dart';
import 'package:edushare/models/notification_model.dart';
import 'package:edushare/widgets/glass_card.dart';

/// Full notification list screen.
/// Opened from the notification bell badge in the app bar.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch full notification list when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationService>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final svc = context.watch<NotificationService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (svc.notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () => svc.markAllAsRead(),
              child: const Text(
                'Mark all read',
                style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
        ],
      ),
      body: svc.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : svc.notifications.isEmpty
              ? _empty(theme)
              : RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: () => svc.fetchNotifications(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: svc.notifications.length,
                    itemBuilder: (context, index) {
                      final n = svc.notifications[index];
                      return _NotificationTile(
                        notification: n,
                        onTap: () => svc.markAsRead(n.id),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _empty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 60, color: theme.disabledColor),
          const SizedBox(height: 14),
          Text('No notifications yet',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('You\'ll be notified when something needs your attention.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Notification Tile ────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  Color _typeColor() {
    if (notification.isApproval) return const Color(0xFF10B981);
    if (notification.isRejection) return const Color(0xFFEF4444);
    return AppTheme.primaryColor; // upload_assigned
  }

  IconData _typeIcon() {
    if (notification.isApproval) return Icons.check_circle_rounded;
    if (notification.isRejection) return Icons.cancel_rounded;
    return Icons.assignment_rounded; // upload_assigned
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
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
    final color = _typeColor();
    final isUnread = !notification.isRead;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coloured icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_typeIcon(), color: color, size: 20),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(notification.createdAt),
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 11, color: theme.disabledColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
