/// notification_service.dart — ChangeNotifier that owns the notification
/// list and unread badge count for the logged-in user.
///
/// Call [refresh()] on app resume or dashboard entry.
/// The notification badge in the shell and screens observes [unreadCount].

import 'package:flutter/foundation.dart';
import 'package:edushare/core/services/api_client.dart';
import 'package:edushare/models/notification_model.dart';

class NotificationService extends ChangeNotifier {
  final _api = ApiClient.instance;

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  // ─── Fetch notifications list ──────────────────────────────────────────
  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.get('/api/notifications') as List<dynamic>;
      _notifications =
          data.map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)).toList();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    } catch (_) {
      // Fail silently — notifications are non-critical
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Fetch only the badge count (lightweight poll) ─────────────────────
  Future<void> refreshUnreadCount() async {
    try {
      final data =
          await _api.get('/api/notifications/unread-count') as Map<String, dynamic>;
      final count = (data['count'] as num?)?.toInt() ?? 0;
      if (count != _unreadCount) {
        _unreadCount = count;
        notifyListeners();
      }
    } catch (_) {
      // Fail silently
    }
  }

  // ─── Mark a single notification as read ───────────────────────────────
  Future<void> markAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1) return;

    final was = _notifications[idx];
    if (was.isRead) return; // already read

    // Optimistic update
    _notifications[idx] = was.copyWith(isRead: true);
    if (_unreadCount > 0) _unreadCount--;
    notifyListeners();

    try {
      await _api.put('/api/notifications/read/$id', {});
    } catch (_) {
      // Roll back optimistic update on failure
      _notifications[idx] = was;
      if (!was.isRead) _unreadCount++;
      notifyListeners();
    }
  }

  // ─── Mark all as read ─────────────────────────────────────────────────
  Future<void> markAllAsRead() async {
    final hadUnread = _unreadCount > 0;
    if (!hadUnread) return;

    // Optimistic update
    _notifications =
        _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _unreadCount = 0;
    notifyListeners();

    try {
      await _api.put('/api/notifications/read-all', {});
    } catch (_) {
      // On failure re-fetch to get actual state
      await fetchNotifications();
    }
  }

  // ─── Clear on logout ──────────────────────────────────────────────────
  void clear() {
    _notifications = [];
    _unreadCount = 0;
    _isLoading = false;
    notifyListeners();
  }
}
