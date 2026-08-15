import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/role_helper.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/widgets/glass_card.dart';
import 'package:edushare/widgets/notification_bell.dart';
import 'package:edushare/widgets/app_bar_profile_avatar.dart';
import 'package:edushare/widgets/pdf_viewer_screen.dart';
import 'package:edushare/views/course/video_details_screen.dart';

/// Approval screen for admin-class roles with tabs:
/// - Tab 0: Materials (pending material uploads)
/// - Tab 1: Contributors (pending contributor registrations)
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({Key? key}) : super(key: key);

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _service = FirestoreService();
  late TabController _tabController;

  List<MaterialModel> _pendingMaterials = [];
  List<UserModel> _pendingContributors = [];
  bool _isLoadingMaterials = true;
  bool _isLoadingContributors = true;
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMaterials();
    _loadContributors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoadingMaterials = true);
    try {
      final materials = await _service.getPendingMaterials();
      if (mounted) {
        setState(() {
          _pendingMaterials = materials;
          _isLoadingMaterials = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMaterials = false);
    }
  }

  Future<void> _loadContributors() async {
    setState(() => _isLoadingContributors = true);
    try {
      final contributors = await _service.getPendingContributors();
      if (mounted) {
        setState(() {
          _pendingContributors = contributors;
          _isLoadingContributors = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingContributors = false);
    }
  }

  // ── Preview Helper ─────────────────────────────────────────────────────

  Future<void> _previewMaterial(MaterialModel mat) async {
    if (mat.type == 'video' || mat.isCloudinaryVideo || mat.isYouTube) {
      final previewCourse = CourseModel(
        id: mat.courseId,
        code: mat.department,
        name: mat.title,
        departmentId: mat.departmentId ?? '',
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoDetailsScreen(
            course: previewCourse,
            allCourseVideos: [mat],
            initialVideo: mat,
          ),
        ),
      );
      return;
    }

    if (mat.isPdf && mat.fileUrl != null && mat.fileUrl!.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            url: mat.fileUrl!,
            title: mat.title,
            materialId: mat.id,
          ),
        ),
      );
      return;
    }

    final urlStr = mat.fileUrl ?? mat.videoLink;
    if (urlStr == null || urlStr.trim().isEmpty) {
      _showSnack('No link or file available to preview.', const Color(0xFFEF4444));
      return;
    }

    final uri = Uri.parse(urlStr.trim());
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _showSnack('Could not open preview in browser.', const Color(0xFFEF4444));
      }
    } catch (e) {
      _showSnack('Failed to launch preview: $e', const Color(0xFFEF4444));
    }
  }

  // ── Material Actions ───────────────────────────────────────────────────

  Future<void> _approveMaterial(MaterialModel mat) async {
    final reviewComment = await _showApproveDialog(mat.title);
    if (reviewComment == null) return; // User cancelled

    setState(() => _processingIds.add(mat.id));
    try {
      await _service.updateMaterialStatus(
        mat.id,
        'approved',
        reviewComment: reviewComment,
      );
      if (mounted) {
        setState(() {
          _pendingMaterials.removeWhere((m) => m.id == mat.id);
          _processingIds.remove(mat.id);
        });
        _showSnack('Material approved successfully.', const Color(0xFF10B981));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingIds.remove(mat.id));
        _showSnack('Failed to approve material: $e', const Color(0xFFEF4444));
      }
    }
  }

  Future<void> _rejectMaterial(MaterialModel mat) async {
    final result = await _showRejectDialog('Material', mat.title);
    if (result == null) return;

    setState(() => _processingIds.add(mat.id));
    try {
      await _service.updateMaterialStatus(
        mat.id,
        'rejected',
        reason: result['reason'],
        reviewComment: result['reviewComment'],
      );
      if (mounted) {
        setState(() {
          _pendingMaterials.removeWhere((m) => m.id == mat.id);
          _processingIds.remove(mat.id);
        });
        _showSnack('Material rejected.', const Color(0xFFEF4444));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingIds.remove(mat.id));
        _showSnack('Failed to reject material: $e', const Color(0xFFEF4444));
      }
    }
  }

  // ── Contributor Actions ───────────────────────────────────────────────

  Future<void> _approveContributor(UserModel user) async {
    setState(() => _processingIds.add(user.uid));
    try {
      await _service.approveContributor(user.uid);
      if (mounted) {
        setState(() {
          _pendingContributors.removeWhere((u) => u.uid == user.uid);
          _processingIds.remove(user.uid);
        });
        _showSnack('${user.name} approved as Contributor.', const Color(0xFF10B981));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingIds.remove(user.uid));
        _showSnack('Failed to approve contributor: $e', const Color(0xFFEF4444));
      }
    }
  }

  Future<void> _rejectContributor(UserModel user) async {
    final result = await _showRejectDialog('Contributor', user.name);
    if (result == null) return;

    setState(() => _processingIds.add(user.uid));
    try {
      await _service.rejectContributor(user.uid, reason: result['reason']);
      if (mounted) {
        setState(() {
          _pendingContributors.removeWhere((u) => u.uid == user.uid);
          _processingIds.remove(user.uid);
        });
        _showSnack('${user.name}\'s registration rejected.', const Color(0xFFEF4444));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingIds.remove(user.uid));
        _showSnack('Failed to reject contributor: $e', const Color(0xFFEF4444));
      }
    }
  }

  // ── Approve Dialog ────────────────────────────────────────────────────

  Future<String?> _showApproveDialog(String title) async {
    final commentCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 8),
            Text('Approve Material', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$title"',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: Theme.of(ctx).disabledColor),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: commentCtrl,
              maxLines: 2,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'Add an optional review comment for the contributor…',
                hintStyle: const TextStyle(fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
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
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, commentCtrl.text.trim()),
            child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Rejection Dialog ──────────────────────────────────────────────────

  Future<Map<String, String>?> _showRejectDialog(String type, String nameOrTitle) async {
    final reasonCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: 8),
            Text('Reject $type',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"$nameOrTitle"',
                style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                    color: Theme.of(ctx).disabledColor),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                maxLength: 300,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Rejection Reason *',
                  hintText: 'Why is this being rejected?',
                  hintStyle: const TextStyle(fontSize: 13),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              if (type == 'Material') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: commentCtrl,
                  maxLines: 2,
                  maxLength: 300,
                  decoration: InputDecoration(
                    labelText: 'Review Comment (Optional)',
                    hintText: 'Additional feedback for contributor…',
                    hintStyle: const TextStyle(fontSize: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
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
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a rejection reason.'),
                    backgroundColor: Color(0xFFEF4444),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, {
                'reason': reason,
                'reviewComment': commentCtrl.text.trim(),
              });
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
                  const Icon(Icons.folder_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Materials (${_pendingMaterials.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_outline_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Contributors (${_pendingContributors.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 0: Materials ──
          _isLoadingMaterials
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: _loadMaterials,
                  child: _pendingMaterials.isEmpty
                      ? _buildEmptyState(
                          theme,
                          isFacultyAdmin
                              ? 'No pending materials assigned to you.'
                              : 'No pending materials to review.',
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          itemCount: _pendingMaterials.length,
                          itemBuilder: (context, index) {
                            final mat = _pendingMaterials[index];
                            final isProcessing =
                                _processingIds.contains(mat.id);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              child: _PendingMaterialCard(
                                mat: mat,
                                theme: theme,
                                isProcessing: isProcessing,
                                isSuperAdmin: currentUser?.isSuperAdmin ?? false,
                                onPreview: () => _previewMaterial(mat),
                                onApprove: () => _approveMaterial(mat),
                                onReject: () => _rejectMaterial(mat),
                              ),
                            );
                          },
                        ),
                ),

          // ── Tab 1: Contributors ──
          _isLoadingContributors
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: _loadContributors,
                  child: _pendingContributors.isEmpty
                      ? _buildEmptyState(
                          theme,
                          isFacultyAdmin
                              ? 'No pending contributor registrations for your department.'
                              : 'No pending contributor registrations.',
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          itemCount: _pendingContributors.length,
                          itemBuilder: (context, index) {
                            final user = _pendingContributors[index];
                            final isProcessing =
                                _processingIds.contains(user.uid);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              child: _PendingContributorCard(
                                user: user,
                                theme: theme,
                                isProcessing: isProcessing,
                                onApprove: () => _approveContributor(user),
                                onReject: () => _rejectContributor(user),
                              ),
                            );
                          },
                        ),
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Center(
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
            message,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Pending Material Card ─────────────────────────────────────────────────

class _PendingMaterialCard extends StatelessWidget {
  final MaterialModel mat;
  final ThemeData theme;
  final bool isProcessing;
  final bool isSuperAdmin;
  final VoidCallback onPreview;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingMaterialCard({
    required this.mat,
    required this.theme,
    required this.isProcessing,
    this.isSuperAdmin = false,
    required this.onPreview,
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
          if (isProcessing)
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primaryColor),
              ),
            )
          else if (isSuperAdmin)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Preview Material',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: onPreview,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                // Preview Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Preview',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: onPreview,
                ),
                const SizedBox(width: 8),
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
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: onReject,
                  ),
                ),
                const SizedBox(width: 8),
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
                            fontWeight: FontWeight.bold, fontSize: 12)),
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

// ─── Pending Contributor Card ──────────────────────────────────────────────

class _PendingContributorCard extends StatelessWidget {
  final UserModel user;
  final ThemeData theme;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingContributorCard({
    required this.user,
    required this.theme,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.accentColor.withOpacity(0.2),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'C',
                  style: const TextStyle(
                      color: AppTheme.accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(user.email,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (user.department.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.school_outlined,
                    size: 14, color: theme.disabledColor),
                const SizedBox(width: 6),
                Text(
                  'Dept: ${user.department}',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ],
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
