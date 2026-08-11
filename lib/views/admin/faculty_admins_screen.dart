import 'package:flutter/material.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/core/role_helper.dart';
import 'package:edushare/widgets/glass_card.dart';
import 'package:edushare/widgets/notification_bell.dart';
import 'package:edushare/widgets/app_bar_profile_avatar.dart';

/// Super Admin screen to manage Admin registrations.
/// Tab 0: Pending (approve / reject with reason)
/// Tab 1: All Admins (disable / enable / delete)
class FacultyAdminsScreen extends StatefulWidget {
  const FacultyAdminsScreen({Key? key}) : super(key: key);

  @override
  State<FacultyAdminsScreen> createState() => _FacultyAdminsScreenState();
}

class _FacultyAdminsScreenState extends State<FacultyAdminsScreen>
    with SingleTickerProviderStateMixin {
  final _service = FirestoreService();
  late TabController _tabController;

  List<UserModel> _pending = [];
  List<UserModel> _all = [];
  bool _loadingPending = true;
  bool _loadingAll = true;
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPending();
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPending() async {
    try {
      final list = await _service.getPendingFacultyAdmins();
      if (mounted) setState(() { _pending = list; _loadingPending = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  Future<void> _loadAll() async {
    try {
      final list = await _service.getAllFacultyAdmins();
      if (mounted) setState(() { _all = list; _loadingAll = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  Future<void> _approve(UserModel admin) async {
    setState(() => _processingIds.add(admin.uid));
    try {
      await _service.approveFacultyAdmin(admin.uid);
      setState(() {
        _pending.removeWhere((u) => u.uid == admin.uid);
        _processingIds.remove(admin.uid);
      });
      await _loadAll();
      _showSnack('${admin.name} approved and can now log in.', Colors.green.shade600);
    } catch (e) {
      setState(() => _processingIds.remove(admin.uid));
      _showSnack('Failed to approve: $e', const Color(0xFFEF4444));
    }
  }

  Future<void> _reject(UserModel admin) async {
    // Collect rejection reason via dialog
    final reason = await _rejectReasonDialog(admin.name);
    if (reason == null) return; // user cancelled

    setState(() => _processingIds.add(admin.uid));
    try {
      await _service.rejectFacultyAdmin(admin.uid,
          reason: reason.trim().isNotEmpty ? reason.trim() : null);
      setState(() {
        _pending.removeWhere((u) => u.uid == admin.uid);
        _processingIds.remove(admin.uid);
      });
      _showSnack('${admin.name}\'s registration has been rejected.', const Color(0xFFEF4444));
    } catch (e) {
      setState(() => _processingIds.remove(admin.uid));
      _showSnack('Failed to reject: $e', const Color(0xFFEF4444));
    }
  }

  Future<void> _disable(UserModel admin) async {
    final confirmed = await _confirmDialog(
      'Disable Account',
      'Disable ${admin.name}\'s Admin account? They will not be able to log in.',
      confirmLabel: 'Disable',
      confirmColor: const Color(0xFFF59E0B),
    );
    if (!confirmed) return;

    setState(() => _processingIds.add(admin.uid));
    try {
      await _service.disableFacultyAdmin(admin.uid);
      await _loadAll();
      setState(() => _processingIds.remove(admin.uid));
      _showSnack('${admin.name}\'s account has been disabled.', const Color(0xFFF59E0B));
    } catch (e) {
      setState(() => _processingIds.remove(admin.uid));
      _showSnack('Failed to disable: $e', const Color(0xFFEF4444));
    }
  }

  Future<void> _enable(UserModel admin) async {
    setState(() => _processingIds.add(admin.uid));
    try {
      await _service.enableFacultyAdmin(admin.uid);
      await _loadAll();
      setState(() => _processingIds.remove(admin.uid));
      _showSnack('${admin.name}\'s account has been re-enabled.', Colors.green.shade600);
    } catch (e) {
      setState(() => _processingIds.remove(admin.uid));
      _showSnack('Failed to enable: $e', const Color(0xFFEF4444));
    }
  }

  Future<void> _delete(UserModel admin) async {
    final confirmed = await _confirmDialog(
      'Delete Account',
      'Permanently delete ${admin.name}\'s Admin account? This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: const Color(0xFFEF4444),
    );
    if (!confirmed) return;

    setState(() => _processingIds.add(admin.uid));
    try {
      await _service.deleteFacultyAdmin(admin.uid);
      setState(() {
        _all.removeWhere((u) => u.uid == admin.uid);
        _processingIds.remove(admin.uid);
      });
      _showSnack('${admin.name}\'s account has been permanently deleted.', const Color(0xFFEF4444));
    } catch (e) {
      setState(() => _processingIds.remove(admin.uid));
      _showSnack('Failed to delete: $e', const Color(0xFFEF4444));
    }
  }

  Future<bool> _confirmDialog(
    String title,
    String message, {
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmLabel,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Shows a dialog asking for a rejection reason.
  /// Returns the entered string (possibly empty) if user taps Reject,
  /// or null if user cancelled.
  Future<String?> _rejectReasonDialog(String adminName) async {
    final reasonController = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Reject Registration',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You are rejecting $adminName\'s Admin application.'),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'e.g. Incomplete information provided',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444)),
              onPressed: () => Navigator.pop(ctx, reasonController.text),
              child: const Text('Reject',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    reasonController.dispose();
    return result;
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 180,
        leading: const AppBarProfileAvatar(),
        actions: const [NotificationBell()],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          indicatorColor: AppTheme.primaryColor,
          unselectedLabelColor: theme.disabledColor,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hourglass_top_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Pending (${_pending.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('All (${_all.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PendingTab(
            pending: _pending,
            isLoading: _loadingPending,
            processingIds: _processingIds,
            onApprove: _approve,
            onReject: _reject,
            onRefresh: _loadPending,
          ),
          _AllTab(
            admins: _all,
            isLoading: _loadingAll,
            processingIds: _processingIds,
            onDisable: _disable,
            onEnable: _enable,
            onDelete: _delete,
            onRefresh: _loadAll,
          ),
        ],
      ),
    );
  }
}

// ─── Pending Tab ──────────────────────────────────────────────────────────

class _PendingTab extends StatelessWidget {
  final List<UserModel> pending;
  final bool isLoading;
  final Set<String> processingIds;
  final void Function(UserModel) onApprove;
  final void Function(UserModel) onReject;
  final Future<void> Function() onRefresh;

  const _PendingTab({
    required this.pending,
    required this.isLoading,
    required this.processingIds,
    required this.onApprove,
    required this.onReject,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    if (pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.task_alt_rounded,
                size: 60, color: Color(0xFF10B981)),
            const SizedBox(height: 14),
            Text('All caught up!',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('No pending Admin registrations.',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: pending.length,
        itemBuilder: (context, index) {
          final admin = pending[index];
          final isProcessing = processingIds.contains(admin.uid);
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            child: _FacultyAdminCard(
              admin: admin,
              isProcessing: isProcessing,
              actions: isProcessing
                  ? null
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              side: const BorderSide(color: Color(0xFFEF4444)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('Reject',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () => onReject(admin),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Approve',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () => onApprove(admin),
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

// ─── All Tab ──────────────────────────────────────────────────────────────

class _AllTab extends StatelessWidget {
  final List<UserModel> admins;
  final bool isLoading;
  final Set<String> processingIds;
  final void Function(UserModel) onDisable;
  final void Function(UserModel) onEnable;
  final void Function(UserModel) onDelete;
  final Future<void> Function() onRefresh;

  const _AllTab({
    required this.admins,
    required this.isLoading,
    required this.processingIds,
    required this.onDisable,
    required this.onEnable,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    if (admins.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline_rounded,
                size: 60, color: AppTheme.primaryColor),
            const SizedBox(height: 14),
            Text('No Admins yet.',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: admins.length,
        itemBuilder: (context, index) {
          final admin = admins[index];
          final isProcessing = processingIds.contains(admin.uid);
          final isDisabled = admin.isDisabled;
          final isPending = admin.isPending;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            child: _FacultyAdminCard(
              admin: admin,
              isProcessing: isProcessing,
              actions: isProcessing
                  ? null
                  : Row(
                      children: [
                        if (!isPending)
                          Expanded(
                            child: isDisabled
                                ? OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF10B981),
                                      side: const BorderSide(
                                          color: Color(0xFF10B981)),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                    ),
                                    icon: const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 16),
                                    label: const Text('Enable',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    onPressed: () => onEnable(admin),
                                  )
                                : OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFF59E0B),
                                      side: const BorderSide(
                                          color: Color(0xFFF59E0B)),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                    ),
                                    icon: const Icon(
                                        Icons.block_rounded,
                                        size: 16),
                                    label: const Text('Disable',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    onPressed: () => onDisable(admin),
                                  ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              side: const BorderSide(color: Color(0xFFEF4444)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 16),
                            label: const Text('Delete',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () => onDelete(admin),
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Reusable Faculty Admin Card ──────────────────────────────────────────

class _FacultyAdminCard extends StatelessWidget {
  final UserModel admin;
  final bool isProcessing;
  final Widget? actions;

  const _FacultyAdminCard({
    required this.admin,
    required this.isProcessing,
    this.actions,
  });

  Color _statusColor() {
    switch (admin.status) {
      case 'active': return const Color(0xFF10B981);
      case 'pending': return const Color(0xFFF59E0B);
      case 'disabled': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = admin.name.isNotEmpty
        ? admin.name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : '?';
    final statusColor = _statusColor();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                backgroundImage: (admin.profilePhotoUrl != null &&
                        admin.profilePhotoUrl!.isNotEmpty)
                    ? NetworkImage(admin.profilePhotoUrl!)
                    : null,
                child: (admin.profilePhotoUrl == null ||
                        admin.profilePhotoUrl!.isEmpty)
                    ? Text(initials,
                        style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(admin.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(admin.email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 11, color: theme.disabledColor)),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(admin.statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Details
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _infoChip(theme, Icons.badge_outlined,
                  admin.facultyId ?? 'N/A'),
              _infoChip(theme, Icons.school_outlined, admin.department),
              if (admin.designation != null && admin.designation!.isNotEmpty)
                _infoChip(theme, Icons.work_outline_rounded, admin.designation!),
            ],
          ),
          const SizedBox(height: 14),
          if (isProcessing)
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primaryColor),
              ),
            )
          else if (actions != null)
            actions!,
        ],
      ),
    );
  }

  Widget _infoChip(ThemeData theme, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: theme.disabledColor),
        const SizedBox(width: 4),
        Text(label,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
      ],
    );
  }
}
