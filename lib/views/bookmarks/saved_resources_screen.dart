import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/views/course/video_details_screen.dart';
import 'package:edushare/widgets/pdf_viewer_screen.dart';

/// saved_resources_screen.dart — Figma-matched Library / Saved Resources Screen (node-id=81-3340)
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
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String? _selectedFolder;

  List<Map<String, dynamic>> _folders = [];

  @override
  void initState() {
    super.initState();
    _loadUserFolders();
    _loadSavedResources();
  }

  Future<void> _loadUserFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? folderJson = prefs.getString('user_saved_folders');
      if (folderJson != null && folderJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(folderJson);
        if (mounted) {
          setState(() {
            _folders = decoded.map((item) => {
              'name': item['name'] as String? ?? 'Folder',
              'count': item['count'] as int? ?? 0,
              'updated': item['updated'] as String? ?? 'Just now',
              'color': const Color(0xFF3B82F6),
            }).toList();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveUserFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(_folders.map((f) => {
        'name': f['name'],
        'count': f['count'] ?? 0,
        'updated': f['updated'] ?? 'Just now',
      }).toList());
      await prefs.setString('user_saved_folders', encoded);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedResources() async {
    try {
      final materials = await _firestoreService.getMaterials();
      final saved = materials.where((m) => m.isApproved).toList();
      final continueList = await _firestoreService.getContinueWatching();

      if (mounted) {
        setState(() {
          _allSavedMaterials = saved;
          _filteredMaterials = _allSavedMaterials;
          _continueWatchingItems = continueList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allSavedMaterials = [];
          _filteredMaterials = [];
          _continueWatchingItems = [];
          _isLoading = false;
        });
      }
    }
  }

  void _filterResources(String query) {
    setState(() {
      _filteredMaterials = _allSavedMaterials.where((m) {
        final matchesQuery = m.title.toLowerCase().contains(query.toLowerCase()) ||
            m.description.toLowerCase().contains(query.toLowerCase());
        final matchesCat = _selectedCategory == 'All' ||
            (_selectedCategory == 'Favorite Notes' && m.type == 'pdf') ||
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

    _loadSavedResources();
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
      ).then((_) => _loadSavedResources());
    } else if (m.fileUrl != null && m.fileUrl!.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            url: m.fileUrl!,
            title: m.title,
            materialId: m.id,
          ),
        ),
      );
    }
  }

  void _showCreateFolderDialog() {
    final folderController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Create New Folder', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: folderController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Folder name (e.g. Algorithms)',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () {
              if (folderController.text.trim().isNotEmpty) {
                final newFolder = {
                  'name': folderController.text.trim(),
                  'count': 0,
                  'updated': 'Just now',
                  'color': AppTheme.primaryColor,
                };
                setState(() {
                  _folders.add(newFolder);
                });
                _saveUserFolders();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Folder "${folderController.text.trim()}" created!')),
                );
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 18),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Library options menu clicked')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                        hintText: 'Search saved notes, videos, assignments...',
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
                        final isVideo = (matJson?['type'] as String? ?? 'video').toLowerCase() == 'video';

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
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF1E293B),
                                      AppTheme.primaryDark.withOpacity(0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: isVideo
                                            ? const Icon(Icons.play_circle_fill_rounded,
                                                color: AppTheme.primaryColor, size: 24)
                                            : const Text(
                                                'PDF',
                                                style: TextStyle(
                                                  color: AppTheme.primaryColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
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
                          final isSelected = _selectedFolder == folder['name'];
                          final folderColor = folder['color'] as Color;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFolder = isSelected ? null : folder['name'] as String;
                                _filterResources(_searchController.text);
                              });
                            },
                            onLongPress: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppTheme.darkSurface,
                                  title: Text('Delete "${folder['name']}"?', style: const TextStyle(color: Colors.white)),
                                  content: const Text('Are you sure you want to delete this folder?', style: TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                      onPressed: () {
                                        setState(() {
                                          if (_selectedFolder == folder['name']) _selectedFolder = null;
                                          _folders.removeAt(index);
                                        });
                                        _saveUserFolders();
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Container(
                              width: 140,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? folderColor.withOpacity(0.2)
                                    : isDark
                                        ? AppTheme.darkSurface
                                        : AppTheme.lightCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? folderColor
                                      : isDark
                                          ? AppTheme.darkBorder
                                          : AppTheme.lightBorder,
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
                                        child: Icon(Icons.folder_rounded, color: folderColor, size: 18),
                                      ),
                                      Text(
                                        '${folder['count']}',
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
                                        folder['name'] as String,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        folder['updated'] as String,
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
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _SavedItemCard extends StatefulWidget {
  final MaterialModel material;
  final VoidCallback onTap;

  const _SavedItemCard({required this.material, required this.onTap});

  @override
  State<_SavedItemCard> createState() => _SavedItemCardState();
}

class _SavedItemCardState extends State<_SavedItemCard> {
  bool _isBookmarked = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final m = widget.material;

    Color badgeColor;
    if (m.type == 'video') {
      badgeColor = const Color(0xFF8B5CF6);
    } else if (m.type == 'assignment') {
      badgeColor = const Color(0xFF10B981);
    } else {
      badgeColor = AppTheme.primaryColor;
    }

    return GestureDetector(
      onTap: widget.onTap,
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
              icon: Icon(
                _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: _isBookmarked ? const Color(0xFFF59E0B) : Colors.white38,
                size: 20,
              ),
              onPressed: () {
                setState(() => _isBookmarked = !_isBookmarked);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 1),
                    content: Text(
                      _isBookmarked ? 'Added to Saved Resources' : 'Removed from Saved Resources',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
