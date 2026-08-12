import 'package:flutter/material.dart';
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
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String? _selectedFolder;

  final List<Map<String, dynamic>> _folders = [
    {'name': 'CS245 DB', 'count': 12, 'updated': 'Updated 2d ago', 'color': const Color(0xFF3B82F6)},
    {'name': 'Midterm Prep', 'count': 8, 'updated': 'Updated 1w ago', 'color': const Color(0xFF8B5CF6)},
    {'name': 'Algorithms', 'count': 5, 'updated': 'Updated 3w ago', 'color': const Color(0xFFF59E0B)},
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedResources();
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

      if (mounted) {
        setState(() {
          _allSavedMaterials = saved.isNotEmpty ? saved : _getMockSavedMaterials();
          _filteredMaterials = _allSavedMaterials;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allSavedMaterials = _getMockSavedMaterials();
          _filteredMaterials = _allSavedMaterials;
          _isLoading = false;
        });
      }
    }
  }

  List<MaterialModel> _getMockSavedMaterials() {
    return [
      MaterialModel(
        id: 'mock1',
        title: 'B+ Trees & Indexing Cheatsheet',
        description: 'Comprehensive Database Indexing Guide',
        departmentId: 'cse',
        department: 'CSE',
        courseId: 'cs245',
        type: 'pdf',
        fileUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        uploadedBy: 'Prof. Alan Turing',
        contributorName: 'Prof. Alan Turing',
        views: 1200,
        avgRating: 4.9,
        totalRatings: 42,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      MaterialModel(
        id: 'mock2',
        title: 'Cache Coherence & Pipelining Demo',
        description: 'Computer Architecture Video Lecture',
        departmentId: 'cse',
        department: 'CSE',
        courseId: 'cs102',
        type: 'video',
        videoLink: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        videoSource: 'youtube',
        uploadedBy: 'Prof. Ada Lovelace',
        contributorName: 'Prof. Ada Lovelace',
        views: 3400,
        avgRating: 4.8,
        totalRatings: 88,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      MaterialModel(
        id: 'mock3',
        title: 'Linear Algebra Midterm Sample Sol.',
        description: 'Mathematics Assignment Solutions',
        departmentId: 'math',
        department: 'MATH',
        courseId: 'math101',
        type: 'assignment',
        fileUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        uploadedBy: 'Dr. John von Neumann',
        contributorName: 'Dr. John von Neumann',
        views: 890,
        avgRating: 4.7,
        totalRatings: 29,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];
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

  void _launchMaterial(MaterialModel m) {
    if (m.type == 'video' || m.videoPlaybackUrl != null || m.isYouTube || m.isCloudinaryVideo) {
      final course = CourseModel(
        id: m.courseId.isNotEmpty ? m.courseId : 'cs245',
        name: m.department.isNotEmpty ? m.department : 'Database Systems',
        code: 'CS245',
        departmentId: m.departmentId.isNotEmpty ? m.departmentId : 'cse',
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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            url: m.fileUrl!,
            title: m.title,
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
                setState(() {
                  _folders.add({
                    'name': folderController.text.trim(),
                    'count': 0,
                    'updated': 'Just now',
                    'color': AppTheme.primaryColor,
                  });
                });
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

                  // Continue Reading Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CONTINUE READING',
                        style: TextStyle(
                          color: AppTheme.darkTextSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (_allSavedMaterials.isNotEmpty) _launchMaterial(_allSavedMaterials.first);
                        },
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
                  // Continue Reading Glass Card
                  GestureDetector(
                    onTap: () {
                      if (_allSavedMaterials.isNotEmpty) _launchMaterial(_allSavedMaterials.first);
                    },
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
                            child: const Center(
                              child: Text(
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
                                const Text(
                                  'CS245 • PAGE 14 OF 28',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Database Normalization Guide',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: const LinearProgressIndicator(
                                    value: 0.5,
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
                          '${m.courseId.isNotEmpty ? m.courseId.toUpperCase() : "CS245"} • ${m.type.toUpperCase()}',
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
