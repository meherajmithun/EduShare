import 'package:flutter/material.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/views/course/video_details_screen.dart';
import 'package:edushare/widgets/pdf_viewer_screen.dart';

/// course_details_screen.dart — Figma-matched Course Overview Screen (node-id=79-1477)
class CourseDetailsScreen extends StatefulWidget {
  final CourseModel course;

  const CourseDetailsScreen({super.key, required this.course});

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;

  List<MaterialModel> _notes = [];
  List<MaterialModel> _assignments = [];
  List<MaterialModel> _videos = [];
  List<MaterialModel> _pastPapers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadMaterials();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    try {
      final notes = await _firestoreService.getApprovedMaterials(widget.course.id, type: 'notes');
      final pdfs = await _firestoreService.getApprovedMaterials(widget.course.id, type: 'pdf');
      final assignments = await _firestoreService.getApprovedMaterials(widget.course.id, type: 'assignment');
      final videos = await _firestoreService.getApprovedMaterials(widget.course.id, type: 'video');

      final allNotes = [...notes, ...pdfs];

      if (mounted) {
        setState(() {
          _notes = allNotes.isNotEmpty ? allNotes : _getMockNotes();
          _assignments = assignments.isNotEmpty ? assignments : _getMockAssignments();
          _videos = videos.isNotEmpty ? videos : _getMockVideos();
          _pastPapers = _getMockPastPapers();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _notes = _getMockNotes();
          _assignments = _getMockAssignments();
          _videos = _getMockVideos();
          _pastPapers = _getMockPastPapers();
          _isLoading = false;
        });
      }
    }
  }

  List<MaterialModel> _getMockNotes() {
    return [
      MaterialModel(
        id: 'c1',
        title: 'Ch 1: ER Diagrams & Relational Model',
        description: 'Comprehensive Database Fundamentals Notes',
        departmentId: 'cse',
        department: 'CSE',
        courseId: widget.course.id,
        type: 'pdf',
        fileUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        uploadedBy: 'Dr. Alan Turing',
        uploaderName: 'Dr. Alan Turing',
        uploadedAt: DateTime.now().subtract(const Duration(days: 2)),
        views: 1420,
        avgRating: 4.9,
        totalRatings: 42,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      MaterialModel(
        id: 'c2',
        title: 'Ch 2: Advanced SQL Joins & Views',
        description: 'Database Query Optimization & Views',
        departmentId: 'cse',
        department: 'CSE',
        courseId: widget.course.id,
        type: 'pdf',
        fileUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        uploadedBy: 'Dr. Alan Turing',
        uploaderName: 'Dr. Alan Turing',
        uploadedAt: DateTime.now().subtract(const Duration(days: 5)),
        views: 1100,
        avgRating: 4.8,
        totalRatings: 30,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];
  }

  List<MaterialModel> _getMockAssignments() {
    return [
      MaterialModel(
        id: 'a1',
        title: 'Assignment 1: Relational Algebra & Calculus',
        description: 'Practice problems & solutions',
        departmentId: 'cse',
        department: 'CSE',
        courseId: widget.course.id,
        type: 'assignment',
        fileUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        uploadedBy: 'Dr. Alan Turing',
        uploaderName: 'Dr. Alan Turing',
        uploadedAt: DateTime.now().subtract(const Duration(days: 7)),
        views: 950,
        avgRating: 4.7,
        totalRatings: 25,
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
    ];
  }

  List<MaterialModel> _getMockVideos() {
    return [
      MaterialModel(
        id: 'v1',
        title: 'Ch 2: Relational Algebra & Calculus Video Lecture',
        description: 'Complete video walkthrough with Dr. Alan Turing',
        departmentId: 'cse',
        department: 'CSE',
        courseId: widget.course.id,
        type: 'video',
        videoLink: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        videoSource: 'youtube',
        uploadedBy: 'Dr. Alan Turing',
        uploaderName: 'Dr. Alan Turing',
        uploadedAt: DateTime.now().subtract(const Duration(days: 3)),
        views: 3400,
        avgRating: 4.9,
        totalRatings: 112,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
  }

  List<MaterialModel> _getMockPastPapers() {
    return [
      MaterialModel(
        id: 'p1',
        title: 'Midterm Exam Past Paper 2024 with Solutions',
        description: 'Database Systems Midterm',
        departmentId: 'cse',
        department: 'CSE',
        courseId: widget.course.id,
        type: 'pdf',
        fileUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        uploadedBy: 'Dr. Alan Turing',
        uploaderName: 'Dr. Alan Turing',
        uploadedAt: DateTime.now().subtract(const Duration(days: 12)),
        views: 2100,
        avgRating: 4.9,
        totalRatings: 85,
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
      ),
    ];
  }

  void _launchMaterial(MaterialModel m) {
    if (m.type == 'video' || m.videoPlaybackUrl != null || m.isYouTube || m.isCloudinaryVideo) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoDetailsScreen(
            course: widget.course,
            allCourseVideos: _videos.isNotEmpty ? _videos : [m],
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
              'COURSE OVERVIEW',
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, color: AppTheme.primaryColor, size: 6),
                SizedBox(width: 4),
                Text(
                  'STUDENT',
                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Course Hero Card
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover Photo Header Box
                        SizedBox(
                          height: 110,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=600&auto=format&fit=crop&q=80',
                                fit: BoxFit.cover,
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.8)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.course.code,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.course.name,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              // Instructor Row
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'AT',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('INSTRUCTOR', style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 8, fontWeight: FontWeight.bold)),
                                      Text('Dr. Alan Turing', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Info Pills Row
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _InfoPill(icon: Icons.calendar_today_rounded, label: 'Semester 4'),
                                    const SizedBox(width: 8),
                                    _InfoPill(icon: Icons.star_rounded, iconColor: const Color(0xFFF59E0B), label: '4.9 (320)'),
                                    const SizedBox(width: 8),
                                    _InfoPill(icon: Icons.people_alt_rounded, label: '1,420 Enrolled'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Course Progress Glass Box
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'COURSE PROGRESS',
                              style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                            ),
                            Text(
                              '68%',
                              style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '14 of 20 Lessons Completed',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            value: 0.68,
                            backgroundColor: Colors.white12,
                            color: AppTheme.primaryColor,
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category Filter Tabs Row
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white60,
                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      tabs: const [
                        Tab(text: '📝 Notes'),
                        Tab(text: '📑 Assignments'),
                        Tab(text: '🎥 Videos'),
                        Tab(text: '📄 Past Papers'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Material Lists View
                  SizedBox(
                    height: 280,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(_notes),
                        _buildList(_assignments),
                        _buildList(_videos),
                        _buildList(_pastPapers),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () {
            final targetVideo = _videos.isNotEmpty ? _videos.first : _getMockVideos().first;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VideoDetailsScreen(
                  course: widget.course,
                  allCourseVideos: _videos.isNotEmpty ? _videos : _getMockVideos(),
                  initialVideo: targetVideo,
                ),
              ),
            );
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Continue Learning', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<MaterialModel> materials) {
    if (materials.isEmpty) {
      return const Center(child: Text('No resources found', style: TextStyle(color: Colors.white60)));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: materials.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final mat = materials[index];
        return GestureDetector(
          onTap: () => _launchMaterial(mat),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurface : AppTheme.lightCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkBorder : AppTheme.lightBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    mat.type == 'video'
                        ? Icons.play_arrow_rounded
                        : mat.type == 'assignment'
                            ? Icons.assignment_outlined
                            : Icons.description_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mat.title,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${mat.type.toUpperCase()} • ${mat.views} Views • 2 days ago',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.file_download_outlined, color: Colors.white70, size: 18),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _InfoPill({
    required this.icon,
    this.iconColor = AppTheme.darkTextSecondary,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
