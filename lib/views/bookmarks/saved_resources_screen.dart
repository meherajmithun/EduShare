import 'package:flutter/material.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/views/course/video_details_screen.dart';
import 'package:edushare/widgets/pdf_viewer_screen.dart';
import 'package:edushare/widgets/image_viewer_screen.dart';
import 'package:edushare/views/bookmarks/folder_details_screen.dart';

/// saved_resources_screen.dart — Library / Saved Resources Screen
/// Real backend data with complete student & department isolation.
class SavedResourcesScreen extends StatefulWidget {
  const SavedResourcesScreen({super.key});

  @override
  State<SavedResourcesScreen> createState() => _SavedResourcesScreenState();
}

class _SavedResourcesScreenState extends State<SavedResourcesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  List<MaterialModel> _allSavedMaterials = [];
  List<MaterialModel> _filteredMaterials = [];
  List<Map<String, dynamic>> _continueWatchingItems = [];
  List<Map<String, dynamic>> _folders = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadUserFolders(),
      _loadSavedResources(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUserFolders() async {
    try {
      final res = await _firestoreService.getFolders();
      final list = (res['folders'] as List<dynamic>?) ?? [];
      if (mounted) {
        setState(() {
          _folders = list.cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSavedResources() async {
    try {
      final bookmarks = await _firestoreService.getBookmarks();
      final continueList = await _firestoreService.getContinueWatching();

      final saved = <MaterialModel>[];
      for (final b in bookmarks) {
        final matJson = b['material'];
        if (matJson is Map<String, dynamic>) {
          saved.add(MaterialModel.fromJson(matJson));
        }
      }

      if (mounted) {
        setState(() {
          _allSavedMaterials = saved;
          _filteredMaterials = saved;
          _continueWatchingItems = continueList;
          _filterResources(_searchController.text);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _allSavedMaterials = [];
          _filteredMaterials = [];
          _continueWatchingItems = [];
        });
      }
    }
  }

  void _filterResources(String query) {
    setState(() {
      _filteredMaterials = _allSavedMaterials.where((m) {
        final matchesQuery = query.isEmpty ||
            m.title.toLowerCase().contains(query.toLowerCase()) ||
            m.description.toLowerCase().contains(query.toLowerCase()) ||
            m.contributorName.toLowerCase().contains(query.toLowerCase());

        final matchesCat = _selectedCategory == 'All' ||
            (_selectedCategory == 'Favorite Notes' && (m.isPdf || m.isImage || m.type == 'notes')) ||
            (_selectedCategory == 'Videos' && m.type == 'video') ||
            (_selectedCategory == 'Assignments' && m.type == 'assignment');

        return matchesQuery && matchesCat;
      }).toList();
    });
  }

  void _openContinueWatching(Map<String, dynamic> item) async {
    final matJson = item['material'];
    final courseJson = item['course'];
    if (matJson == null) return;

    final videoMat = MaterialModel.fromJson(matJson as Map<String, dynamic>);
    final course = courseJson != null
        ? CourseModel.fromJson(courseJson as Map<String, dynamic>)
        : CourseModel(
            id: videoMat.courseId.isNotEmpty ? videoMat.courseId : 'course',
            name: videoMat.department.isNotEmpty ? videoMat.department : 'Course',
            code: videoMat.courseId.isNotEmpty ? videoMat.courseId : (videoMat.department.isNotEmpty ? videoMat.department : 'COURSE'),
            departmentId: videoMat.departmentId,
          );

    final allVideos = await _firestoreService.getApprovedMaterials(course.id, type: 'video');
    final allNotes = await _firestoreService.getApprovedMaterials(course.id, type: 'notes');
    final allAssignments = await _firestoreService.getApprovedMaterials(course.id, type: 'assignment');

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoDetailsScreen(
          course: course,
          allCourseVideos: allVideos.isNotEmpty ? allVideos : [videoMat],
          initialVideo: videoMat,
          courseResources: [...allNotes, ...allAssignments],
        ),
      ),
    );

    _loadAllData();
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
      ).then((_) => _loadAllData());
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
        ).then((_) => _loadAllData());
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
        ).then((_) => _loadAllData());
      }
    }
  }

  void _showCreateFolderDialog() {
    final folderController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.create_new_folder_rounded, color: AppTheme.primaryColor, size: 22),
            SizedBox(width: 8),
            Text('Create New Folder', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: folderController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. Algorithm For Mid',
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
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              final name = folderController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);

              try {
                await _firestoreService.createFolder(name);
                await _loadUserFolders();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Folder "$name" created successfully!'),
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
                      content: Text('Could not create folder: ${e.toString()}'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openFolder(Map<String, dynamic> folder) {
    final folderId = (folder['_id'] ?? folder['id'] ?? '').toString();
    final folderName = (folder['name'] as String?) ?? 'Folder';
    if (folderId.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FolderDetailsScreen(
          folderId: folderId,
          initialName: folderName,
          onFolderDeleted: _loadUserFolders,
          onFolderRenamed: (_) => _loadUserFolders(),
        ),
      ),
    ).then((_) => _loadAllData());
  }

  void _showFolderOptions(Map<String, dynamic> folder) {
    final folderId = (folder['_id'] ?? folder['id'] ?? '').toString();
    final folderName = (folder['name'] as String?) ?? 'Folder';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_open_rounded, color: AppTheme.primaryColor),
                title: Text('Open "$folderName"', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openFolder(folder);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.white70),
                title: const Text('Rename Folder', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameFolderDialog(folderId, folderName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Delete Folder', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteFolder(folderId, folderName);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameFolderDialog(String folderId, String currentName) {
    final controller = TextEditingController(text: currentName);

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
              if (newName.isEmpty || newName == currentName) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx);

              try {
                await _firestoreService.renameFolder(folderId, newName);
                await _loadUserFolders();
                if (mounted) {
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

  Future<void> _deleteFolder(String folderId, String folderName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Folder?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Are you sure you want to delete "$folderName"?',
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
      await _firestoreService.deleteFolder(folderId);
      await _loadUserFolders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Folder "$folderName" deleted'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Column(
          children: [
            Text(
              'LIBRARY',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              'Saved Resources',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _loadAllData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterResources,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          icon: Icon(Icons.search_rounded, color: AppTheme.darkTextSecondary),
                          hintText: 'Search saved notes, videos, assignm...',
                          hintStyle: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 13),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Continue Watching Section
                    if (_continueWatchingItems.isNotEmpty) ...[
                      Builder(
                        builder: (context) {
                          final item = _continueWatchingItems.first;
                          final matJson = item['material'] as Map<String, dynamic>?;
                          final courseJson = item['course'] as Map<String, dynamic>?;
                          final progJson = item['progress'] as Map<String, dynamic>?;

                          final title = matJson?['title'] as String? ?? 'In Progress Video';
                          final courseCode = courseJson?['code'] as String? ??
                              (matJson?['courseId'] as String? ?? '');
                          final courseName = courseJson?['name'] as String? ??
                              (matJson?['department'] as String? ?? 'Course');
                          final duration = (progJson?['duration'] as num?)?.toDouble() ?? 0;
                          final lastPosition = (progJson?['lastPosition'] as num?)?.toDouble() ?? 0;
                          final progressVal = duration > 0 ? (lastPosition / duration).clamp(0.0, 1.0) : 0.0;

                          String subtitle;
                          if (courseCode.isNotEmpty) {
                            subtitle = duration > 0
                                ? '$courseCode • ${(progressVal * 100).toInt()}% COMPLETED'
                                : '$courseCode • IN PROGRESS';
                          } else {
                            subtitle = duration > 0
                                ? '$courseName • ${(progressVal * 100).toInt()}% COMPLETED'
                                : '$courseName • IN PROGRESS';
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'CONTINUE WATCHING',
                                    style: TextStyle(
                                      color: AppTheme.darkTextSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _openContinueWatching(item),
                                    child: const Text(
                                      'Resume',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () => _openContinueWatching(item),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          color: AppTheme.primaryColor.withOpacity(0.2),
                                          child: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primaryColor, size: 28),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              subtitle,
                                              style: const TextStyle(
                                                color: AppTheme.primaryColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              title,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: progressVal > 0 ? progressVal : 0.05,
                                                backgroundColor: Colors.white12,
                                                color: AppTheme.primaryColor,
                                                minHeight: 4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: const BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          );
                        },
                      ),
                    ],

                    // Folders Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'FOLDERS',
                          style: TextStyle(
                            color: AppTheme.darkTextSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        GestureDetector(
                          onTap: _showCreateFolderDialog,
                          child: const Row(
                            children: [
                              Icon(Icons.add, size: 14, color: AppTheme.primaryColor),
                              SizedBox(width: 2),
                              Text(
                                'New Folder',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_folders.isEmpty)
                      GestureDetector(
                        onTap: _showCreateFolderDialog,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.create_new_folder_outlined, color: AppTheme.primaryColor, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'No folders created yet. Tap + New Folder to create',
                                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _folders.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final folder = _folders[index];
                            final folderName = (folder['name'] as String?) ?? 'Folder';
                            final count = (folder['count'] as num?)?.toInt() ?? 0;
                            const folderColor = Color(0xFF3B82F6);

                            return GestureDetector(
                              onTap: () => _openFolder(folder),
                              onLongPress: () => _showFolderOptions(folder),
                              child: Container(
                                width: 140,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: folderColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.folder_rounded, color: folderColor, size: 18),
                                        ),
                                        Text(
                                          '$count',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          folderName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Just now',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.4),
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Saved Items Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SAVED ITEMS',
                          style: TextStyle(
                            color: AppTheme.darkTextSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          '${_filteredMaterials.length} Total Items',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Category Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'Favorite Notes', 'Videos', 'Assignments'].map((cat) {
                          final isSel = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                cat,
                                style: TextStyle(
                                  color: isSel ? Colors.white : Colors.white60,
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              selected: isSel,
                              selectedColor: AppTheme.primaryColor,
                              backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                              side: BorderSide(
                                color: isSel ? AppTheme.primaryColor : AppTheme.darkBorder,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedCategory = cat;
                                    _filterResources(_searchController.text);
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Material Items List
                    if (_filteredMaterials.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.bookmark_border_rounded, size: 48, color: theme.disabledColor),
                              const SizedBox(height: 12),
                              Text(
                                'No saved resources found',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap the Bookmark or Save icon on any PDF, image, or video to add it here.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.disabledColor, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredMaterials.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _filteredMaterials[index];
                          return _SavedItemCard(
                            material: item,
                            onTap: () => _launchMaterial(item),
                            onUnbookmark: () async {
                              await _firestoreService.removeBookmark(item.id);
                              _loadAllData();
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SavedItemCard extends StatelessWidget {
  final MaterialModel material;
  final VoidCallback onTap;
  final VoidCallback onUnbookmark;

  const _SavedItemCard({
    required this.material,
    required this.onTap,
    required this.onUnbookmark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final m = material;

    Color badgeColor;
    if (m.type == 'video') {
      badgeColor = const Color(0xFF8B5CF6);
    } else if (m.type == 'assignment') {
      badgeColor = const Color(0xFF10B981);
    } else {
      badgeColor = AppTheme.primaryColor;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Thumbnail preview or type badge box
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      m.computedThumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: badgeColor.withOpacity(0.15),
                        child: Center(
                          child: Text(
                            m.type.toUpperCase(),
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (m.type == 'video')
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: const Center(
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Title & Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${m.courseId.isNotEmpty ? m.courseId.toUpperCase() : (m.department.isNotEmpty ? m.department.toUpperCase() : "RESOURCE")} • ${m.type.toUpperCase()}',
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 2),
                      Text(
                        m.avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${m.views} views)',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Bookmark star icon button
            IconButton(
              icon: const Icon(
                Icons.bookmark_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              onPressed: onUnbookmark,
              tooltip: 'Remove from saved',
            ),
          ],
        ),
      ),
    );
  }
}
