/// user_stats_provider.dart — ChangeNotifier that holds real learning statistics
/// for the currently logged-in user.
///
/// Sources data from GET /api/users/me/stats (backed by VideoProgress &
/// VideoBookmark documents).
///
/// Usage:
///   context.read<UserStatsProvider>().refresh();
///   final stats = context.watch<UserStatsProvider>();

import 'package:flutter/material.dart';
import 'package:edushare/core/services/api_client.dart';

/// A single entry in the weekly activity chart.
class DayActivity {
  final String day;   // 'Mon', 'Tue', etc.
  final double hours; // hours studied that day

  const DayActivity({required this.day, required this.hours});

  factory DayActivity.fromJson(Map<String, dynamic> json) {
    return DayActivity(
      day: json['day'] as String? ?? '',
      hours: (json['hours'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class UserStatsProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;

  int _downloads = 0;
  int _savedNotes = 0;
  int _completed = 0;
  double _totalWeeklyHours = 0.0;
  List<DayActivity> _weeklyActivity = [];

  // ─── Public getters ────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;
  int get downloads => _downloads;
  int get savedNotes => _savedNotes;
  int get completed => _completed;
  double get totalWeeklyHours => _totalWeeklyHours;
  List<DayActivity> get weeklyActivity => _weeklyActivity;

  /// Fetch stats from the API. Safe to call multiple times.
  /// Pass [force: true] to bypass the already-loaded guard.
  Future<void> refresh({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !force) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final raw = await ApiClient.instance.get('/api/users/me/stats');
      final data = raw as Map<String, dynamic>;

      _downloads = (data['downloads'] as num?)?.toInt() ?? 0;
      _savedNotes = (data['savedNotes'] as num?)?.toInt() ?? 0;
      _completed = (data['completed'] as num?)?.toInt() ?? 0;
      _totalWeeklyHours = (data['totalWeeklyHours'] as num?)?.toDouble() ?? 0.0;

      final rawActivity = data['weeklyActivity'] as List<dynamic>? ?? [];
      _weeklyActivity = rawActivity
          .map((e) => DayActivity.fromJson(e as Map<String, dynamic>))
          .toList();

      _hasLoaded = true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reset stats — call on logout so stale data never shows for the next user.
  void reset() {
    _downloads = 0;
    _savedNotes = 0;
    _completed = 0;
    _totalWeeklyHours = 0.0;
    _weeklyActivity = [];
    _hasLoaded = false;
    _error = null;
    notifyListeners();
  }
}
