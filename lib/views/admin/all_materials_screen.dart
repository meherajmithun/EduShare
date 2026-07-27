import 'package:flutter/material.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/widgets/glass_card.dart';

/// Admin All Materials screen — lists every material across all statuses.
/// Shows approval audit fields: assigned admin, approved by, rejection reason.
/// Scoped to assignedAdmin for Faculty Admins (handled by the API).
class AllMaterialsScreen extends StatefulWidget {
  const AllMaterialsScreen({Key? key}) : super(key: key);

  @override
  State<AllMaterialsScreen> createState() => _AllMaterialsScreenState();
}

class _AllMaterialsScreenState extends State<AllMaterialsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<MaterialModel> _allMaterials = [];
  List<MaterialModel> _filteredMaterials = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    try {
      final all = await _firestoreService.getAllMaterials();
      if (mounted) {
        setState(() {
          _allMaterials = all;
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
        ? List.from(_allMaterials)
        : _allMaterials
            .where((m) => m.approvalStatus == status)
            .toList();
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Material',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Are you sure you want to permanently delete this material?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _firestoreService.deleteMaterial(id);
      setState(() {
        _allMaterials.removeWhere((m) => m.id == id);
        _filteredMaterials.removeWhere((m) => m.id == id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Material deleted.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('All Materials',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadMaterials,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Column(
              children: [
                // ── Filter chips ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('all',
                            'All (${_allMaterials.length})', null, theme),
                        const SizedBox(width: 8),
                        _chip('approved', 'Approved',
                            const Color(0xFF10B981), theme),
                        const SizedBox(width: 8),
                        _chip('pending', 'Pending',
                            const Color(0xFFF59E0B), theme),
                        const SizedBox(width: 8),
                        _chip('rejected', 'Rejected',
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
                              Icon(Icons.folder_open_rounded,
                                  size: 54, color: theme.disabledColor),
                              const SizedBox(height: 12),
                              Text('No materials found.',
                                  style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppTheme.primaryColor,
                          onRefresh: _loadMaterials,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 4),
                            itemCount: _filteredMaterials.length,
                            itemBuilder: (context, index) {
                              final mat = _filteredMaterials[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: _MaterialCard(
                                  mat: mat,
                                  theme: theme,
                                  onDelete: () => _delete(mat.id),
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

  Widget _chip(
      String status, String label, Color? color, ThemeData theme) {
    final isSelected = _filterStatus == status;
    final chipColor = color ?? AppTheme.primaryColor;
    return GestureDetector(
      onTap: () => setState(() => _applyFilter(status)),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withOpacity(0.15) : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? chipColor : theme.dividerColor,
              width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
              color: isSelected
                  ? chipColor
                  : theme.textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            )),
      ),
    );
  }
}

// ─── Material Card ─────────────────────────────────────────────────────────

class _MaterialCard extends StatelessWidget {
  final MaterialModel mat;
  final ThemeData theme;
  final VoidCallback onDelete;

  const _MaterialCard({
    required this.mat,
    required this.theme,
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

  Color _statusColor() {
    if (mat.approvalStatus == 'approved') return const Color(0xFF10B981);
    if (mat.approvalStatus == 'rejected') return const Color(0xFFEF4444);
    return const Color(0xFFF59E0B);
  }

  String _statusLabel() {
    if (mat.approvalStatus == 'approved') return 'Approved';
    if (mat.approvalStatus == 'rejected') return 'Rejected';
    return 'Pending';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final isRejected = mat.approvalStatus == 'rejected';
    final isApproved = mat.approvalStatus == 'approved';
    final isPending = mat.approvalStatus == 'pending';

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main row ────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _typeColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_typeIcon(),
                    color: _typeColor(), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mat.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 3),
                    Text('By ${mat.contributorName}',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontSize: 11)),
                    const SizedBox(height: 5),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(_statusLabel(),
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444), size: 20),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),

          // ── Department ───────────────────────────────────────────────
          if (mat.department.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.school_outlined,
                    size: 13, color: theme.disabledColor),
                const SizedBox(width: 5),
                Text(mat.department,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontSize: 11)),
              ],
            ),
          ],

          // ── Assigned admin (pending) ─────────────────────────────────
          if (isPending && mat.assignedAdminName != null) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(Icons.assignment_ind_outlined,
                    size: 13, color: Color(0xFFF59E0B)),
                const SizedBox(width: 5),
                Text('Reviewer: ${mat.assignedAdminName}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 11, color: const Color(0xFFF59E0B))),
              ],
            ),
          ],

          if (isPending && mat.assignedAdminName == null) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 13, color: theme.disabledColor),
                const SizedBox(width: 5),
                Text('No Faculty Admin assigned',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontSize: 11)),
              ],
            ),
          ],

          // ── Approved by ──────────────────────────────────────────────
          if (isApproved && mat.approvedByName != null) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(Icons.verified_outlined,
                    size: 13, color: Color(0xFF10B981)),
                const SizedBox(width: 5),
                Text(
                  'Approved by ${mat.approvedByName}' +
                      (mat.approvedAt != null
                          ? ' · ${_formatDate(mat.approvedAt!)}'
                          : ''),
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 11, color: const Color(0xFF10B981)),
                ),
              ],
            ),
          ],

          // ── Rejection reason ─────────────────────────────────────────
          if (isRejected &&
              mat.rejectionReason != null &&
              mat.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cancel_outlined,
                          size: 12, color: Color(0xFFEF4444)),
                      const SizedBox(width: 5),
                      Text(
                        'Rejected${mat.approvedByName != null ? ' by ${mat.approvedByName}' : ''}',
                        style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mat.rejectionReason!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                        color: const Color(0xFFEF4444).withOpacity(0.8)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
