import 'package:flutter/material.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/views/course/video_details_screen.dart';
import 'package:edushare/widgets/glass_card.dart';

class WatchHistoryScreen extends StatefulWidget {
  final int initialTab;
  const WatchHistoryScreen({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  State<WatchHistoryScreen> createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends State<WatchHistoryScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;

  List<Map<String, dynamic>> _continueWatching = [];
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _bookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _loadData();
  }

  void _loadData() async {
    try {
      final continueList = await _firestoreService.getContinueWatching();
      final historyList = await _firestoreService.getWatchHistory();
      final bookmarksList = await _firestoreService.getBookmarks();

      if (mounted) {
        setState(() {
          _continueWatching = continueList;
          _history = historyList;
          _bookmarks = bookmarksList;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openVideo(Map<String, dynamic> item) async {
    final matJson = item['material'];
    final courseJson = item['course'];

    if (matJson == null || courseJson == null) return;

    final videoMat = MaterialModel.fromJson(matJson as Map<String, dynamic>);
    final course = CourseModel.fromJson(courseJson as Map<String, dynamic>);

    // Fetch all videos for this course
    final allVideos = await _firestoreService.getApprovedMaterials(course.id, type: 'video');
    final allNotes = await _firestoreService.getApprovedMaterials(course.id, type: 'notes');
    final allAssignments = await _firestoreService.getApprovedMaterials(course.id, type: 'assignment');

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoDetailsScreen(
          course: course,
          allCourseVideos: allVideos,
          initialVideo: videoMat,
          courseResources: [...allNotes, ...allAssignments],
        ),
      ),
    );

    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Video Library'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: theme.disabledColor,
          tabs: const [
            Tab(text: 'Continue Watching'),
            Tab(text: 'Bookmarks'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildVideoList(_continueWatching, emptyMsg: 'No unfinished videos in progress'),
                _buildVideoList(_bookmarks, emptyMsg: 'No bookmarked videos'),
                _buildVideoList(_history, emptyMsg: 'No watch history yet'),
              ],
            ),
    );
  }

  Widget _buildVideoList(List<Map<String, dynamic>> items, {required String emptyMsg}) {
    final theme = Theme.of(context);

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 54, color: theme.disabledColor),
            const SizedBox(height: 12),
            Text(emptyMsg, style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final matJson = item['material'];
        final courseJson = item['course'];
        if (matJson == null) return const SizedBox.shrink();

        final title = matJson['title'] as String? ?? 'Untitled Video';
        final contributor = matJson['contributorName'] as String? ?? 'EduShare';
        final courseCode = courseJson?['code'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.play_circle_fill_rounded, color: Colors.redAccent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('$courseCode • By $contributor', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11, color: theme.disabledColor)),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  onPressed: () => _openVideo(item),
                  child: const Text('Watch', style: TextStyle(fontSize: 12, color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
