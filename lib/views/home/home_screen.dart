import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/providers/theme_provider.dart';
import 'package:edushare/core/providers/user_stats_provider.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/department_model.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/models/student_course_progress_model.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/widgets/notification_bell.dart';
import 'package:edushare/views/course/course_details_screen.dart';
import 'package:edushare/views/course/video_details_screen.dart';
import 'package:edushare/views/course/watch_history_screen.dart';
import 'package:edushare/views/course/completed_courses_screen.dart';
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
  List<StudentCourseProgressModel> _continueLearning = [];
  List<StudentCourseProgressModel> _completedCourses = [];
  bool _isLoading = true;
  DepartmentModel? _selectedDept;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Kick off stats fetch (non-blocking)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserStatsProvider>().refresh();
    });
  }

  Future<void> _loadData() async {
    try {
      final depts = await _firestoreService.getDepartments();

      // Load courses for current user's department first, then all others
      final user = context.read<AuthService>().currentUser;
      List<CourseModel> courses = [];
      if (user != null && user.departmentId != null && user.departmentId!.isNotEmpty) {
        // Prefer the user's own department courses first
        final myDeptCourses = await _firestoreService.getCourses(user.departmentId!);
        courses.addAll(myDeptCourses);
      }
      // Also load other departments' courses so filters work
      for (var dept in depts) {
        if (user?.departmentId == dept.id) continue; // already loaded
        final deptCourses = await _firestoreService.getCourses(dept.id);
        courses.addAll(deptCourses);
      }

      final materials = await _firestoreService.getMaterials();
      final approved = materials.where((m) => m.isApproved).toList();
      // Sort trending by views descending
      approved.sort((a, b) => b.views.compareTo(a.views));

      // Load real student learning progress (continue learning & completed courses)
      final progressData = await _firestoreService.getStudentLearningProgress();
      final contList = (progressData['continueLearning'] as List<dynamic>? ?? [])
          .map((e) => StudentCourseProgressModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final compList = (progressData['completedCourses'] as List<dynamic>? ?? [])
          .map((e) => StudentCourseProgressModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _departments = depts;
          _allCourses = courses;
          _filteredCourses = courses;
          _trendingMaterials = approved.take(10).toList();
          _continueLearning = contList;
          _completedCourses = compList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _departments = [];
          _allCourses = [];
          _filteredCourses = [];
          _trendingMaterials = [];
          _continueLearning = [];
          _completedCourses = [];
          _isLoading = false;
        });
      }
    }
  }

  void _selectDepartment(DepartmentModel? dept) {
    setState(() {
      _selectedDept = dept;
      if (dept == null) {
        _filteredCourses = _allCourses;
      } else {
        _filteredCourses = _allCourses
            .where((c) => c.departmentId == dept.id || c.code.contains(dept.code))
            .toList();
      }
    });
  }

  void _openContinueLearningCourse(StudentCourseProgressModel item) async {
    final course = CourseModel(
      id: item.id,
      name: item.name,
      code: item.code,
      departmentId: item.departmentId,
    );

    // Fetch all videos for this course
    final allVideos = await _firestoreService.getApprovedMaterials(course.id, type: 'video');
    final allNotes = await _firestoreService.getApprovedMaterials(course.id, type: 'notes');
    final allAssignments = await _firestoreService.getApprovedMaterials(course.id, type: 'assignment');

    if (!mounted) return;

    if (allVideos.isNotEmpty) {
      // Find the specific last watched video or fallback to first
      MaterialModel initialVideo = allVideos.first;
      if (item.lastWatchedVideoId != null && item.lastWatchedVideoId!.isNotEmpty) {
        final found = allVideos.where((v) => v.id == item.lastWatchedVideoId);
        if (found.isNotEmpty) {
          initialVideo = found.first;
        }
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoDetailsScreen(
            course: course,
            allCourseVideos: allVideos,
            initialVideo: initialVideo,
            courseResources: [...allNotes, ...allAssignments],
          ),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CourseDetailsScreen(course: course),
        ),
      );
    }

    if (mounted) {
      _loadData();
      context.read<UserStatsProvider>().refresh(force: true);
    }
  }

  void _launchMaterial(MaterialModel m) {
    if (m.type == 'video' || m.videoPlaybackUrl != null || m.isYouTube || m.isCloudinaryVideo) {
      final course = CourseModel(
        id: m.courseId.isNotEmpty ? m.courseId : 'unknown',
        name: m.department.isNotEmpty ? m.department : 'Course',
        code: '',
        departmentId: m.departmentId.isNotEmpty ? m.departmentId : 'unknown',
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
            materialId: m.id,
          ),
        ),
      );
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = context.select<AuthService, UserModel?>((s) => s.currentUser);
    final stats = context.watch<UserStatsProvider>();
    final themeProvider = context.read<ThemeProvider>();

    // Dynamic role badge label — never show internal names
    final roleBadge = () {
      switch (currentUser?.role) {
        case 'contributor':
          return 'CONTRIBUTOR';
        case 'faculty_admin':
        case 'admin':
          return 'ADMIN';
        case 'super_admin':
          return 'ADMIN';
        default:
          return 'STUDENT';
      }
    }();

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
            child: Row(
              children: [
                const Icon(Icons.circle, color: AppTheme.primaryColor, size: 8),
                const SizedBox(width: 6),
                Text(
                  '$roleBadge DASHBOARD',
                  style: const TextStyle(
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
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () async {
                await _loadData();
                if (mounted) context.read<UserStatsProvider>().refresh(force: true);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── User Profile Greeting Header ────────────────────────
                    Row(
                      children: [
                        // Avatar
                        GestureDetector(
                          onTap: () {
                            // Navigate to profile via shell tabs — handled by parent
                          },
                          child: _UserAvatar(user: currentUser),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _greeting(),
                                style: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      currentUser?.name.split(' ').first ?? '...',
                                      style: TextStyle(
                                        color: isDark
                                            ? AppTheme.darkTextPrimary
                                            : AppTheme.lightTextPrimary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      roleBadge,
                                      style: const TextStyle(
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
                        // Dark/Light mode toggle wired to ThemeProvider
                        IconButton(
                          icon: Icon(
                            isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            themeProvider.setTheme(
                              isDark ? ThemeMode.light : ThemeMode.dark,
                            );
                          },
                        ),
                        const NotificationBell(),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Search Bar ──────────────────────────────────────────
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
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary),
                            const SizedBox(width: 12),
                            Text(
                              'Search courses, notes, or contributors...',
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Department Filter Chips ──────────────────────────────
                    if (_departments.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: const Text('All'),
                                selected: _selectedDept == null,
                                selectedColor: AppTheme.primaryColor,
                                backgroundColor:
                                    isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                                labelStyle: TextStyle(
                                  color: _selectedDept == null
                                      ? Colors.white
                                      : (isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.lightTextSecondary),
                                  fontWeight: _selectedDept == null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
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
                                  backgroundColor:
                                      isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                                  labelStyle: TextStyle(
                                    color: isSel
                                        ? Colors.white
                                        : (isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.lightTextSecondary),
                                    fontWeight:
                                        isSel ? FontWeight.bold : FontWeight.normal,
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

                    // ── 3 Metric Grid Cards (Real stats from UserStatsProvider) ──
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.file_download_outlined,
                            iconColor: const Color(0xFF3B82F6),
                            count: stats.isLoading ? '–' : '${stats.downloads}',
                            label: 'ENGAGED',
                            isDark: isDark,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const WatchHistoryScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.bookmark_border_rounded,
                            iconColor: const Color(0xFF10B981),
                            count: stats.isLoading ? '–' : '${stats.savedNotes}',
                            label: 'SAVED NOTES',
                            isDark: isDark,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const SavedResourcesScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                            count: stats.isLoading ? '–' : '${_completedCourses.isNotEmpty ? _completedCourses.length : stats.completed}',
                            label: 'COMPLETED',
                            isDark: isDark,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const CompletedCoursesScreen()),
                              ).then((_) {
                                _loadData();
                                if (mounted) context.read<UserStatsProvider>().refresh(force: true);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Continue Learning Section (Real backend in-progress courses) ──
                    if (_continueLearning.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Continue Learning',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.lightTextPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const WatchHistoryScreen()),
                              ).then((_) {
                                _loadData();
                                if (mounted) context.read<UserStatsProvider>().refresh(force: true);
                              });
                            },
                            child: const Text(
                              'View All',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._continueLearning.take(3).map((item) => _ContinueLearningCard(
                            progress: item,
                            isDark: isDark,
                            onTap: () => _openContinueLearningCourse(item),
                          )),
                      const SizedBox(height: 24),
                    ],

                    // ── Available Courses Section ───────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available Courses',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.lightTextPrimary,
                          ),
                        ),
                        if (_filteredCourses.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CourseDetailsScreen(course: _filteredCourses.first),
                                ),
                              );
                            },
                            child: const Text(
                              'View All',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_filteredCourses.isEmpty)
                      _EmptyState(
                        icon: Icons.menu_book_rounded,
                        message: 'No courses available yet.',
                        isDark: isDark,
                      )
                    else
                      ..._filteredCourses.take(3).map((course) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CourseCard(
                              course: course,
                              isDark: isDark,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CourseDetailsScreen(course: course),
                                ),
                              ),
                            ),
                          )),
                    const SizedBox(height: 24),

                    // ── Trending Notes Section ──────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Trending Notes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.lightTextPrimary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const SearchScreen()),
                            );
                          },
                          child: const Text(
                            'Explore',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_trendingMaterials.isEmpty)
                      _EmptyState(
                        icon: Icons.article_rounded,
                        message: 'No approved materials yet.',
                        isDark: isDark,
                      )
                    else
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
                              isDark: isDark,
                              onTap: () => _launchMaterial(item),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  final UserModel? user;
  const _UserAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.profilePhotoUrl;
    final name = user?.name ?? '';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: (photoUrl == null || photoUrl.isEmpty)
            ? const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        image: (photoUrl != null && photoUrl.isNotEmpty)
            ? DecorationImage(
                image: NetworkImage(photoUrl),
                fit: BoxFit.cover,
                onError: (_, __) {},
              )
            : null,
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5), width: 2),
      ),
      child: (photoUrl == null || photoUrl.isEmpty)
          ? Center(
              child: Text(
                initials,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String count;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

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
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
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

class _CourseCard extends StatelessWidget {
  final CourseModel course;
  final bool isDark;
  final VoidCallback onTap;

  const _CourseCard({
    required this.course,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

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
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    course.code,
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
          ],
        ),
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final MaterialModel material;
  final bool isDark;
  final VoidCallback onTap;

  const _TrendingCard({required this.material, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                          style: const TextStyle(
                              color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
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
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${material.views} views',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    fontSize: 9,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 11),
                    Text(
                      material.avgRating.toStringAsFixed(1),
                      style: TextStyle(
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        fontSize: 9,
                      ),
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isDark;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        children: [
          Icon(icon,
              size: 36,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueLearningCard extends StatelessWidget {
  final StudentCourseProgressModel progress;
  final bool isDark;
  final VoidCallback onTap;

  const _ContinueLearningCard({
    required this.progress,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (progress.progressPercentage.clamp(0, 100)) / 100.0;

    final isCode = progress.code.toLowerCase().contains('cse') ||
        progress.name.toLowerCase().contains('code') ||
        progress.name.toLowerCase().contains('program') ||
        progress.name.toLowerCase().contains('structure') ||
        progress.name.toLowerCase().contains('algorithm');

    final icon = isCode ? Icons.code_rounded : Icons.storage_rounded;
    final iconBg = isCode ? const Color(0xFFEF4444).withOpacity(0.15) : const Color(0xFF3B82F6).withOpacity(0.15);
    final iconColor = isCode ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          progress.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          progress.instructor,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${progress.progressPercentage}%',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Linear progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 5,
                  backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

