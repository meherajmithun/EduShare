import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/widgets/glass_card.dart';

class CourseDetailsScreen extends StatefulWidget {
  final CourseModel course;

  const CourseDetailsScreen({Key? key, required this.course}) : super(key: key);

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;
  
  List<MaterialModel> _notes = [];
  List<MaterialModel> _assignments = [];
  List<MaterialModel> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMaterials();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadMaterials() async {
    try {
      final notes = await _firestoreService.getApprovedMaterials(widget.course.id, type: 'notes');
      final assignments = await _firestoreService.getApprovedMaterials(widget.course.id, type: 'assignment');
      final videos = await _firestoreService.getApprovedMaterials(widget.course.id, type: 'video');
      
      setState(() {
        _notes = notes;
        _assignments = assignments;
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open link'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _playYoutubeVideo(String videoUrl) {
    final videoId = YoutubePlayer.convertUrlToId(videoUrl);
    if (videoId == null) {
      _openUrl(videoUrl);
      return;
    }

    // Play in a custom overlay dialog or bottom sheet for high-fidelity!
    showDialog(
      context: context,
      builder: (context) {
        final YoutubePlayerController controller = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: false,
          ),
        );

        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.symmetric(horizontal: 10),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: YoutubePlayer(
              controller: controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: AppTheme.primaryColor,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.course.code)),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.course.code, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              widget.course.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: theme.brightness == Brightness.dark 
              ? AppTheme.darkTextSecondary 
              : AppTheme.lightTextSecondary,
          labelStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Notes', icon: Icon(Icons.description_rounded, size: 20)),
            Tab(text: 'Assignments', icon: Icon(Icons.assignment_turned_in_rounded, size: 20)),
            Tab(text: 'Video Lectures', icon: Icon(Icons.video_library_rounded, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMaterialList(_notes, isVideo: false),
          _buildMaterialList(_assignments, isVideo: false),
          _buildMaterialList(_videos, isVideo: true),
        ],
      ),
    );
  }

  Widget _buildMaterialList(List<MaterialModel> materials, {required bool isVideo}) {
    final theme = Theme.of(context);

    if (materials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isVideo ? Icons.video_call_rounded : Icons.folder_open_rounded,
              size: 54,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 12),
            Text(
              isVideo ? 'No video lectures available' : 'No document files available',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: materials.length,
      itemBuilder: (context, index) {
        final mat = materials[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon type
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isVideo ? Colors.redAccent : AppTheme.primaryColor).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isVideo
                            ? Icons.play_circle_fill_rounded
                            : mat.type == 'assignment'
                                ? Icons.task_rounded
                                : Icons.text_snippet_rounded,
                        color: isVideo ? Colors.redAccent : AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title & Description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mat.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            mat.description,
                            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Contributor details + Action Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Contributor Info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(
                            mat.contributorName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Shared by ${mat.contributorName}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // Open / Play Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: isVideo ? Colors.redAccent : AppTheme.primaryColor,
                      ),
                      onPressed: () {
                        if (isVideo && mat.videoLink != null) {
                          _playYoutubeVideo(mat.videoLink!);
                        } else {
                          _openUrl(mat.fileUrl);
                        }
                      },
                      child: Row(
                        children: [
                          Icon(
                            isVideo ? Icons.play_arrow_rounded : Icons.open_in_new_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVideo ? 'Play' : 'Open',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
