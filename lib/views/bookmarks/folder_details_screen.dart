import 'package:flutter/material.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/views/course/video_details_screen.dart';
import 'package:edushare/widgets/pdf_viewer_screen.dart';
import 'package:edushare/widgets/image_viewer_screen.dart';
import 'package:edushare/widgets/glass_card.dart';

class FolderDetailsScreen extends StatefulWidget {
  final String folderId;
  final String initialName;
  final VoidCallback? onFolderDeleted;
  final ValueChanged<String>? onFolderRenamed;

  const FolderDetailsScreen({
    super.key,
    required this.folderId,
    required this.initialName,
    this.onFolderDeleted,
    this.onFolderRenamed,
  });

  @override
  State<FolderDetailsScreen> createState() => _FolderDetailsScreenState();
}

class _FolderDetailsScreenState extends State<FolderDetailsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  late String _folderName;
  List<MaterialModel> _materials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _folderName = widget.initialName;
    _loadFolderMaterials();
  }

  Future<void> _loadFolderMaterials() async {
    setState(() => _isLoading = true);
    try {
      final res = await _firestoreService.getFolderMaterials(widget.folderId);
      final folderData = res['folder'] as Map<String, dynamic>?;
      if (folderData != null && folderData['name'] != null) {
        _folderName = folderData['name'] as String;
      }

      final items = (res['items'] as List<dynamic>?) ?? [];
      final list = <MaterialModel>[];

      for (final item in items) {
        final matJson = item['material'];
        if (matJson is Map<String, dynamic>) {
          list.add(MaterialModel.fromJson(matJson));
        }
      }

      if (mounted) {
        setState(() {
          _materials = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _folderName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Folder', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Folder Name',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == _folderName) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx);

              try {
                await _firestoreService.renameFolder(widget.folderId, newName);
                if (mounted) {
                  setState(() => _folderName = newName);
                  widget.onFolderRenamed?.call(newName);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Folder renamed to "$newName"'),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to rename: ${e.toString()}'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Rename', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFolder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Folder?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Are you sure you want to delete "$_folderName"? Saved resources inside will be unlinked.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestoreService.deleteFolder(widget.folderId);
      if (mounted) {
        widget.onFolderDeleted?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Folder "$_folderName" deleted'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete folder: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _removeMaterial(MaterialModel mat) async {
    try {
      await _firestoreService.removeMaterialFromFolder(widget.folderId, mat.id);
      setState(() {
        _materials.removeWhere((m) => m.id == mat.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${mat.title}" from folder'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _launchMaterial(MaterialModel m) {
    if (m.type == 'video' || m.videoPlaybackUrl != null || m.isYouTube || m.isCloudinaryVideo) {
      final course = CourseModel(
        id: m.courseId.isNotEmpty ? m.courseId : 'course',
        name: m.department.isNotEmpty ? m.department : 'Course',
        code: m.courseId.isNotEmpty ? m.courseId : (m.department.isNotEmpty ? m.department : 'COURSE'),
        departmentId: m.departmentId.isNotEmpty ? m.departmentId : '',
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoDetailsScreen(
            course: course,
            allCourseVideos: [m],
            initialVideo: m,
          ),
        ),
      );
    } else if (m.fileUrl != null && m.fileUrl!.isNotEmpty) {
      if (m.isImage) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ImageViewerScreen(
              url: m.fileUrl!,
              title: m.title,
              materialId: m.id,
              courseName: m.department,
              contributorName: m.contributorName,
              createdAt: m.createdAt,
              courseId: m.courseId,
            ),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              url: m.fileUrl!,
              title: m.title,
              materialId: m.id,
              courseName: m.department,
              contributorName: m.contributorName,
              createdAt: m.createdAt,
              courseId: m.courseId,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.folder_rounded, color: AppTheme.primaryColor, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _folderName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'rename') _showRenameDialog();
              if (val == 'delete') _deleteFolder();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: AppTheme.primaryColor, size: 18),
                    SizedBox(width: 10),
                    Text('Rename Folder', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                    SizedBox(width: 10),
                    Text('Delete Folder', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _loadFolderMaterials,
              child: _materials.isEmpty
                  ? _buildEmptyState(theme)
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      children: [
                        Text(
                          '${_materials.length} ${_materials.length == 1 ? 'Resource' : 'Resources'} Saved',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.disabledColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._materials.map((mat) => _buildMaterialCard(mat, theme, isDark)),
                      ],
                    ),
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(
              'This folder is empty',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Open any PDF, image, or video in EduShare and tap the Save button to organize it into "$_folderName".',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.disabledColor, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialCard(MaterialModel mat, ThemeData theme, bool isDark) {
    Color typeColor = AppTheme.primaryColor;
    IconData typeIcon = Icons.description_outlined;
    String typeLabel = 'PDF Note';

    if (mat.type == 'video') {
      typeColor = Colors.redAccent;
      typeIcon = Icons.play_circle_outline_rounded;
      typeLabel = 'Video';
    } else if (mat.isImage) {
      typeColor = const Color(0xFF10B981);
      typeIcon = Icons.image_outlined;
      typeLabel = 'Image Note';
    } else if (mat.type == 'assignment') {
      typeColor = const Color(0xFFF59E0B);
      typeIcon = Icons.assignment_outlined;
      typeLabel = 'Assignment';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: InkWell(
          onTap: () => _launchMaterial(mat),
          borderRadius: BorderRadius.circular(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(typeIcon, color: typeColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mat.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(color: typeColor, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mat.description,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (mat.contributorName.isNotEmpty) ...[
                          Icon(Icons.person_outline_rounded, size: 12, color: theme.disabledColor),
                          const SizedBox(width: 4),
                          Text(
                            mat.contributorName,
                            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
                          ),
                          const SizedBox(width: 10),
                        ],
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                          tooltip: 'Remove from folder',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _removeMaterial(mat),
                        ),
                      ],
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
