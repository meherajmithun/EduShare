/// notification_bell.dart — App bar bell icon with animated unread badge.
///
/// Usage:
///   AppBar(
///     actions: [NotificationBell()],
///   )
///
/// Tapping opens NotificationsScreen and refreshes the count.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/services/notification_service.dart';
import 'package:edushare/views/notifications/notifications_screen.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final count =
        context.select<NotificationService, int>((s) => s.unreadCount);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        tooltip: count > 0 ? '$count unread' : 'Notifications',
        onPressed: () => _open(context),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_outlined, size: 26),
            if (count > 0)
              Positioned(
                right: -4,
                top: -4,
                child: _Badge(count: count),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const NotificationsScreen(),
          fullscreenDialog: false),
    );
    // Refresh badge count when returning from notification screen
    if (context.mounted) {
      context.read<NotificationService>().refreshUnreadCount();
    }
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: count > 0 ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).scaffoldBackgroundColor,
            width: 1.5,
          ),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
