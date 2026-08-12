import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/department_model.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/widgets/glass_card.dart';
import 'package:edushare/widgets/notification_bell.dart';
import 'package:edushare/widgets/app_bar_profile_avatar.dart';
import 'package:edushare/views/course/course_details_screen.dart';
import 'package:edushare/views/course/video_details_screen.dart';
import 'package:edushare/views/course/watch_history_screen.dart';
import 'package:edushare/views/home/search_screen.dart';
import 'package:edushare/views/bookmarks/saved_resources_screen.dart';
import 'package:edushare/widgets/pdf_viewer_screen.dart';

/// home_screen.dart — Figma-matched Student Dashboard / Home Screen (node-id=71-293)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<DepartmentModel> _departments = [];
  List<CourseModel> _allCourses = [];
  List<CourseModel> _filteredCourses = [];
  List<MaterialModel> _trendingMaterials = [];
  bool _isLoading = true;
  DepartmentModel? _selectedDept;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final depts = await _firestoreService.getDepartments();
      List<CourseModel> courses = [];
      for (var dept in depts) {
        final deptCourses = await _firestoreService.getCourses(dept.id);
        courses.addAll(deptCourses);
      }

      final materials = await _firestoreService.getMaterials();
      final approved = materials.where((m) => m.isApproved).toList();

      if (mounted) {
        setState(() {
          _departments = depts;
          _allCourses = courses.isNotEmpty ? courses : _getMockCourses();
          _filteredCourses = _allCourses;
          _trendingMaterials = approved.isNotEmpty ? approved : _getMockTrendingMaterials();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _departments = _getMockDepartments();
          _allCourses = _getMockCourses();
          _filteredCourses = _allCourses;
          _trendingMaterials = _getMockTrendingMaterials();
          _isLoading = false;
        });
      }
    }
  }

  List<DepartmentModel> _getMockDepartments() {
    return [
      DepartmentModel(id: 'cse', name: 'Computer Science', code: 'CSE'),
      DepartmentModel(id: 'bba', name: 'Business Admin', code: 'BBA'),
      DepartmentModel(id: 'eee', name: 'Electrical Eng', code: 'EEE'),
      DepartmentModel(id: 'arts', name: 'Arts & Design', code: 'Arts'),
    ];
  }

  List<CourseModel> _getMockCourses() {
    return [
      const CourseModel(
        id: 'cs301',
        name: 'Database Systems',
        code: 'CSE-301',
        departmentId: 'cse',
      ),
      const CourseModel(
        id: 'cs102',
        name: 'Data Structures',
        code: 'CSE-102',
        departmentId: 'cse',
      ),
      const CourseModel(
        id: 'eee201',
        name: 'Circuit Analysis',
        code: 'EEE-201',
        departmentId: 'eee',
      ),
      const CourseModel(
        id: 'bba101',
        name: 'Principles of Mgt',
        code: 'BBA-101',
        departmentId: 'bba',
      ),
    ];
  }

  List<MaterialModel> _getMockTrendingMaterials() {
    return [
      MaterialModel(
        id: 'trend1',
        title: 'B+ Trees & Indexing Cheatsheet',
        description: 'Database Systems Notes',
        departmentId: 'cse',
        department: 'CSE',
        courseId: 'cs301',
        type: 'pdf',
        fileUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        uploadedBy: 'Prof. Alan Turing',
        contributorName: 'Prof. Alan Turing',
        views: 1420,
        avgRating: 4.9,
        totalRatings: 32,
        createdAt: DateTime.now(),
      ),
      MaterialModel(
        id: 'trend2',
        title: 'Cache Coherence & Pipelining Demo',
        description: 'Computer Architecture Video',
        departmentId: 'cse',
        department: 'CSE',
        courseId: 'cs102',
        type: 'video',
        videoLink: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        videoSource: 'youtube',
        uploadedBy: 'Prof. Ada Lovelace',
        contributorName: 'Prof. Ada Lovelace',
        views: 2800,
        avgRating: 4.8,
        totalRatings: 54,
        createdAt: DateTime.now(),
      ),
    ];
  }

  void _selectDepartment(DepartmentModel? dept) {
    setState(() {
      _selectedDept = dept;
      if (dept == null) {
        _filteredCourses = _allCourses;
      } else {
        _filteredCourses = _allCourses.where((c) => c.departmentId == dept.id || c.code.contains(dept.code)).toList();
      }
    });
  }

  void _launchMaterial(MaterialModel m) {
    if (m.type == 'video' || m.videoPlaybackUrl != null || m.isYouTube || m.isCloudinaryVideo) {
      final course = CourseModel(
        id: m.courseId.isNotEmpty ? m.courseId : 'cs301',
        name: m.department.isNotEmpty ? m.department : 'Database Systems',
        code: 'CSE-301',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = context.select<AuthService, UserModel?>((s) => s.currentUser);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 160,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'PORTAL MODE',
                style: TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'EduShare',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, color: AppTheme.primaryColor, size: 8),
                SizedBox(width: 6),
                Text(
                  'STUDENT DASHBOARD',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
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
                  // User Profile Greeting Header
                  Row(
                    children: [
                      const AppBarProfileAvatar(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Good Morning,',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  currentUser?.name ?? 'John Doe',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'STUDENT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Action Icons: Dark Mode + Bell
                      IconButton(
                        icon: const Icon(Icons.nightlight_round, color: Colors.white70, size: 20),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Toggled Dark Mode')),
                          );
                        },
                      ),
                      const NotificationBell(),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Search Bar Input
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: const Row(
                        children: [
                          Icon(Icons.search_rounded, color: AppTheme.darkTextSecondary),
                          SizedBox(width: 12),
                          Text(
                            'Search courses, notes, or contributors...',
                            style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Department Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('All Departments'),
                            selected: _selectedDept == null,
                            selectedColor: AppTheme.primaryColor,
                            backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                            labelStyle: TextStyle(
                              color: _selectedDept == null ? Colors.white : Colors.white60,
                              fontWeight: _selectedDept == null ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (_) => _selectDepartment(null),
                          ),
                        ),
                        ..._departments.map((dept) {
                          final isSel = _selectedDept?.id == dept.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(dept.code),
                              selected: isSel,
                              selectedColor: AppTheme.primaryColor,
                              backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : Colors.white60,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (_) => _selectDepartment(dept),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3 Metric Grid Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.file_download_outlined,
                          iconColor: const Color(0xFF3B82F6),
                          count: '124',
                          label: 'DOWNLOADS',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SavedResourcesScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.bookmark_border_rounded,
                          iconColor: const Color(0xFF10B981),
                          count: '48',
                          label: 'SAVED NOTES',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SavedResourcesScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          count: '12',
                          label: 'COMPLETED',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const WatchHistoryScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Continue Learning Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Continue Learning',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (_filteredCourses.isNotEmpty) {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => CourseDetailsScreen(course: _filteredCourses.first)),
                            );
                          }
                        },
                        child: const Text(
                          'View All',
                          style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Course Progress Cards
                  _CourseProgressCard(
                    title: 'Database Systems',
                    instructor: 'Prof. Alan Turing',
                    progress: 0.75,
                    percentageText: '75%',
                    icon: Icons.storage_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    onTap: () {
                      final c = _allCourses.firstWhere(
                        (element) => element.name.contains('Database'),
                        orElse: () => _getMockCourses().first,
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CourseDetailsScreen(course: c)),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _CourseProgressCard(
                    title: 'Data Structures',
                    instructor: 'Prof. Ada Lovelace',
                    progress: 0.40,
                    percentageText: '40%',
                    icon: Icons.code_rounded,
                    iconColor: const Color(0xFFEF4444),
                    onTap: () {
                      final c = _allCourses.firstWhere(
                        (element) => element.name.contains('Data'),
                        orElse: () => _getMockCourses()[1],
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CourseDetailsScreen(course: c)),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Trending Notes Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Trending Notes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SavedResourcesScreen()),
                          );
                        },
                        child: const Text(
                          'Explore',
                          style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Trending Cards Horizontal Scroll
                  SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _trendingMaterials.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = _trendingMaterials[index];
                        return _TrendingCard(
                          material: item,
                          onTap: () => _launchMaterial(item),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String count;
  final String label;
  final VoidCallback onTap;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseProgressCard extends StatelessWidget {
  final String title;
  final String instructor;
  final double progress;
  final String percentageText;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _CourseProgressCard({
    required this.title,
    required this.instructor,
    required this.progress,
    required this.percentageText,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        instructor,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  percentageText,
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white12,
                color: AppTheme.primaryColor,
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final MaterialModel material;
  final VoidCallback onTap;

  const _TrendingCard({required this.material, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      material.computedThumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        child: const Icon(Icons.article_rounded, color: AppTheme.primaryColor),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          material.type.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              material.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${material.views} views',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9),
                ),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 10, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 2),
                    Text(
                      material.avgRating.toStringAsFixed(1),
                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
