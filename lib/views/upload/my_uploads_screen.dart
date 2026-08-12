import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/widgets/glass_card.dart';
import 'package:edushare/widgets/notification_bell.dart';
import 'package:edushare/widgets/app_bar_profile_avatar.dart';

/// Shows the current contributor/admin user's own uploaded materials
/// with live pending / approved / rejected status, assigned reviewer,
/// and rejection reason when applicable.
class MyUploadsScreen extends StatefulWidget {
  /// Optional pre-selected filter. Pass 'approved', 'pending', or 'rejected'
  /// to open the screen with that tab already selected.
  final String initialFilter;

  const MyUploadsScreen({Key? key, this.initialFilter = 'all'}) : super(key: key);

  @override
  State<MyUploadsScreen> createState() => _MyUploadsScreenState();
}

class _MyUploadsScreenState extends State<MyUploadsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<MaterialModel> _myMaterials = [];
  List<MaterialModel> _filteredMaterials = [];
  bool _isLoading = true;
  late String _filterStatus;

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialFilter;
    _loadMyUploads();
  }

  Future<void> _loadMyUploads() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final uid = authService.currentUser?.uid ?? '';
    setState(() => _isLoading = true);
    try {
      final materials = await _firestoreService.getMyMaterials(uid);
      if (mounted) {
        setState(() {
          _myMaterials = materials;
          _applyFilter(_filterStatus);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String status) {
    _filterStatus = status;
    _filteredMaterials = status == 'all'
        ? List.from(_myMaterials)
        : _myMaterials.where((m) => m.approvalStatus == status).toList();
  }

  Future<void> _delete(MaterialModel mat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Material',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Permanently delete "${mat.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _firestoreService.deleteMaterial(mat.id);
      setState(() {
        _myMaterials.removeWhere((m) => m.id == mat.id);
        _applyFilter(_filterStatus);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Material deleted.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Status summary counts
    final pendingCount =
        _myMaterials.where((m) => m.approvalStatus == 'pending').length;
    final approvedCount =
        _myMaterials.where((m) => m.approvalStatus == 'approved').length;
    final rejectedCount =
        _myMaterials.where((m) => m.approvalStatus == 'rejected').length;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 180,
        leading: const AppBarProfileAvatar(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadMyUploads,
          ),
          const NotificationBell(),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Column(
              children: [
                // ── Status summary strip ──────────────────────────────
                if (_myMaterials.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        _summaryTile(theme, isDark, 'Pending', pendingCount,
                            const Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        _summaryTile(theme, isDark, 'Approved', approvedCount,
                            const Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        _summaryTile(theme, isDark, 'Rejected', rejectedCount,
                            const Color(0xFFEF4444)),
                      ],
                    ),
                  ),

                // ── Filter chips ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('all', 'All (${_myMaterials.length})',
                            null, theme),
                        const SizedBox(width: 8),
                        _filterChip('pending', 'Pending ($pendingCount)',
                            const Color(0xFFF59E0B), theme),
                        const SizedBox(width: 8),
                        _filterChip('approved', 'Approved ($approvedCount)',
                            const Color(0xFF10B981), theme),
                        const SizedBox(width: 8),
                        _filterChip('rejected', 'Rejected ($rejectedCount)',
                            const Color(0xFFEF4444), theme),
                      ],
                    ),
                  ),
                ),

                // ── List ─────────────────────────────────────────────
                Expanded(
                  child: _filteredMaterials.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_outlined,
                                  size: 54, color: theme.disabledColor),
                              const SizedBox(height: 12),
                              Text(
                                _filterStatus == 'all'
                                    ? "You haven't uploaded anything yet."
                                    : "No $_filterStatus materials.",
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppTheme.primaryColor,
                          onRefresh: _loadMyUploads,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 4),
                            itemCount: _filteredMaterials.length,
                            itemBuilder: (context, index) {
                              final mat = _filteredMaterials[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: _UploadCard(
                                  mat: mat,
                                  theme: theme,
                                  isDark: isDark,
                                  onDelete: () => _delete(mat),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _summaryTile(ThemeData theme, bool isDark, String label, int count,
      Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            Text(count.toString(),
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
            Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String status, String label, Color? color, ThemeData theme) {
    final isSelected = _filterStatus == status;
    final chipColor = color ?? AppTheme.primaryColor;
    return GestureDetector(
      onTap: () => setState(() => _applyFilter(status)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withOpacity(0.15) : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : theme.dividerColor,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? chipColor : theme.textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Upload Card Widget ────────────────────────────────────────────────────

class _UploadCard extends StatelessWidget {
  final MaterialModel mat;
  final ThemeData theme;
  final bool isDark;
  final VoidCallback onDelete;

  const _UploadCard({
    required this.mat,
    required this.theme,
    required this.isDark,
    required this.onDelete,
  });

  Color _typeColor() {
    if (mat.type == 'video') return Colors.redAccent;
    if (mat.type == 'assignment') return const Color(0xFFF59E0B);
    return AppTheme.primaryColor;
  }

  IconData _typeIcon() {
    if (mat.type == 'video') return Icons.play_circle_outline_rounded;
    if (mat.type == 'assignment') return Icons.assignment_outlined;
    return Icons.description_outlined;
  }

  String _typeLabel() {
    if (mat.type == 'video') return 'Video';
    if (mat.type == 'assignment') return 'Assignment';
    return 'Notes';
  }

  Color _statusColor() {
    if (mat.approvalStatus == 'approved') return const Color(0xFF10B981);
    if (mat.approvalStatus == 'rejected') return const Color(0xFFEF4444);
    return const Color(0xFFF59E0B);
  }

  IconData _statusIcon() {
    if (mat.approvalStatus == 'approved') return Icons.check_circle_outline_rounded;
    if (mat.approvalStatus == 'rejected') return Icons.cancel_outlined;
    return Icons.hourglass_top_rounded;
  }

  String _statusLabel() {
    if (mat.approvalStatus == 'approved') return 'Approved';
    if (mat.approvalStatus == 'rejected') return 'Rejected';
    return 'Pending Review';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final isRejected = mat.approvalStatus == 'rejected';
    final isPending = mat.approvalStatus == 'pending';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: icon + title + status badge ────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _typeColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_typeIcon(), color: _typeColor(), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mat.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mat.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(), color: statusColor, size: 12),
                    const SizedBox(width: 3),
                    Text(_statusLabel(),
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Meta row ───────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.folder_outlined,
                  size: 13, color: theme.disabledColor),
              const SizedBox(width: 4),
              Text(_typeLabel(),
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
              const SizedBox(width: 12),
              Icon(Icons.calendar_today_outlined,
                  size: 13, color: theme.disabledColor),
              const SizedBox(width: 4),
              Text(_formatDate(mat.createdAt),
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
            ],
          ),

          // ── Pending: show assigned Faculty Admin ────────────────────
          if (isPending && mat.assignedAdminName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_ind_outlined,
                      size: 14, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Assigned to: ${mat.assignedAdminName}',
                      style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isPending && mat.assignedAdminName == null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: theme.disabledColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: theme.disabledColor),
                  const SizedBox(width: 6),
                  Text(
                    'No Faculty Admin assigned — Super Admin will review.',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],

          // ── Approved: show who approved + date + review comment ───────
          if (mat.approvalStatus == 'approved' &&
              mat.approvedByName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_outlined,
                          size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Approved by ${mat.approvedByName}' +
                              (mat.approvedAt != null
                                  ? ' · ${_formatDate(mat.approvedAt!)}'
                                  : ''),
                          style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (mat.reviewComment != null && mat.reviewComment!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Comment: "${mat.reviewComment}"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF10B981).withOpacity(0.9)),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── Rejected: show rejection reason ─────────────────────────
          if (isRejected) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cancel_outlined,
                          size: 14, color: Color(0xFFEF4444)),
                      const SizedBox(width: 6),
                      Text(
                        'Rejected${mat.approvedByName != null ? ' by ${mat.approvedByName}' : ''}',
                        style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (mat.rejectionReason != null &&
                      mat.rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Reason: ${mat.rejectionReason}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: const Color(0xFFEF4444).withOpacity(0.8)),
                    ),
                  ],
                  if (mat.reviewComment != null &&
                      mat.reviewComment!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Comment: "${mat.reviewComment}"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFFEF4444).withOpacity(0.8)),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Delete button (only for pending/rejected) ────────────────
          if (mat.approvalStatus != 'approved')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Delete',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: onDelete,
              ),
            ),
        ],
      ),
    );
  }
}
