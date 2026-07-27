import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/role_helper.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/widgets/glass_card.dart';

/// Material approval screen for admin-class roles.
///
/// Faculty Admin: sees only materials where assignedAdmin == their ID.
/// Super Admin / Legacy Admin: sees all pending materials.
///
/// Reject action prompts for a rejection reason before submitting.
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({Key? key}) : super(key: key);

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  final FirestoreService _service = FirestoreService();
  List<MaterialModel> _pending = [];
  bool _isLoading = true;
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoading = true);
    try {
      final pending = await _service.getPendingMaterials();
      if (mounted) {
        setState(() {
          _pending = pending;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Approve ────────────────────────────────────────────────────────────
  Future<void> _approve(MaterialModel mat) async {
    setState(() => _processingIds.add(mat.id));
    try {
      await _service.updateMaterialStatus(mat.id, 'approved');
      if (mounted) {
        setState(() {
          _pending.removeWhere((m) => m.id == mat.id);
          _processingIds.remove(mat.id);
        });
        _showSnack('Material approved successfully.', const Color(0xFF10B981));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingIds.remove(mat.id));
        _showSnack('Failed to approve: $e', const Color(0xFFEF4444));
      }
    }
  }

  // ── Reject — prompts for reason ────────────────────────────────────────
  Future<void> _reject(MaterialModel mat) async {
    final reason = await _showRejectDialog(mat.title);
    if (reason == null) return; // User cancelled

    setState(() => _processingIds.add(mat.id));
    try {
      await _service.updateMaterialStatus(mat.id, 'rejected', reason: reason);
      if (mounted) {
        setState(() {
          _pending.removeWhere((m) => m.id == mat.id);
          _processingIds.remove(mat.id);
        });
        _showSnack('Material rejected.', const Color(0xFFEF4444));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingIds.remove(mat.id));
        _showSnack('Failed to reject: $e', const Color(0xFFEF4444));
      }
    }
  }

  // ── Rejection reason dialog ────────────────────────────────────────────
  Future<String?> _showRejectDialog(String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text('Reject Material',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$title"',
              style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  color: Theme.of(ctx).disabledColor),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 300,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason (optional)…',
                hintStyle: const TextStyle(fontSize: 13),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(
                ctx,
                controller.text.trim().isNotEmpty
                    ? controller.text.trim()
                    : 'No reason provided.',
              );
            },
            child: const Text('Reject',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
    final currentUser =
        context.select<AuthService, UserModel?>((s) => s.currentUser);
    final isFacultyAdmin = currentUser?.isFacultyAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFacultyAdmin ? 'Department Approvals' : 'Pending Approvals',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Text('${_pending.length} pending',
                    style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadPending,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _loadPending,
              child: _pending.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.task_alt_rounded,
                              size: 60, color: Color(0xFF10B981)),
                          const SizedBox(height: 14),
                          Text('All caught up!',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            isFacultyAdmin
                                ? 'No pending materials assigned to you.'
                                : 'No pending materials to review.',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      itemCount: _pending.length,
                      itemBuilder: (context, index) {
                        final mat = _pending[index];
                        final isProcessing =
                            _processingIds.contains(mat.id);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          child: _PendingCard(
                            mat: mat,
                            theme: theme,
                            isProcessing: isProcessing,
                            onApprove: () => _approve(mat),
                            onReject: () => _reject(mat),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

// ─── Pending Material Card ─────────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  final MaterialModel mat;
  final ThemeData theme;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingCard({
    required this.mat,
    required this.theme,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
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
    if (mat.type == 'video') return 'Video Lecture';
    if (mat.type == 'assignment') return 'Assignment';
    return 'Notes';
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _typeColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_typeIcon(), color: _typeColor(), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mat.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(mat.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Contributor & type meta ─────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: AppTheme.primaryColor,
                child: Text(
                  mat.contributorName.isNotEmpty
                      ? mat.contributorName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'By ${mat.contributorName}  ·  ${_typeLabel()}',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),

          // ── Department tag ──────────────────────────────────────────
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

          const SizedBox(height: 14),

          // ── Action buttons ──────────────────────────────────────────
          if (isProcessing)
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primaryColor),
              ),
            )
          else
            Row(
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
                    onPressed: onReject,
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
                    onPressed: onApprove,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
