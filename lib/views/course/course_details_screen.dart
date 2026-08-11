import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/models/contributor_profile_model.dart';
import 'package:edushare/views/profile/contributor_profile_screen.dart';
import 'package:edushare/views/course/video_details_screen.dart';
import 'package:edushare/widgets/glass_card.dart';
import 'package:edushare/widgets/material_rating_sheet.dart';
import 'package:edushare/widgets/pdf_viewer_screen.dart';

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
  Map<String, ContributorProfileModel> _contributorProfiles = {};
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
      final pdfs = await _firestoreService.getApprovedMaterials(widget.course.id, type: 'pdf');
      final assignments = await _firestoreService.getApprovedMaterials(widget.course.id, type: 'assignment');
      final videos = await _firestoreService.getApprovedMaterials(widget.course.id, type: 'video');

      // Merge pdf type materials into the notes list for display
      final allNotes = [...notes, ...pdfs];
      final allMaterials = [...allNotes, ...assignments, ...videos];
      final uniqueContributorIds = allMaterials.map((m) => m.uploadedBy).toSet();

      final profilesMap = <String, ContributorProfileModel>{};
      for (final id in uniqueContributorIds) {
        if (id.isNotEmpty) {
          try {
            final profile = await _firestoreService.getContributorProfile(id);
            profilesMap[id] = profile;
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _notes = allNotes;
          _assignments = assignments;
          _videos = videos;
          _contributorProfiles = profilesMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                    // Tappable Contributor Info Chip with Rating
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        if (mat.uploadedBy.isNotEmpty) {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ContributorProfileScreen(
                                contributorId: mat.uploadedBy,
                                contributorName: mat.contributorName,
                              ),
                            ),
                          );
                          _loadMaterials(); // Refresh rating stats when coming back
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: AppTheme.primaryColor,
                              child: Text(
                                mat.contributorName.isNotEmpty
                                    ? mat.contributorName[0].toUpperCase()
                                    : 'C',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              mat.contributorName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Average rating pill
                            Builder(builder: (context) {
                              final profile = _contributorProfiles[mat.uploadedBy];
                              final avg = profile?.avgRating ?? 0.0;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                                    const SizedBox(width: 2),
                                    Text(
                                      avg > 0 ? avg.toStringAsFixed(1) : 'New',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                    // Action Buttons Row: Rate & Open/Play
                    Row(
                      children: [
                        // Material Rating Button
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            MaterialRatingSheet.show(
                              context,
                              mat,
                              onRatingChanged: _loadMaterials,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  mat.avgRating > 0 ? mat.avgRating.toStringAsFixed(1) : 'Rate',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                                if (mat.totalRatings > 0)
                                  Text(
                                    ' (${mat.totalRatings})',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.disabledColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                         // Open / Play Button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: isVideo ? Colors.redAccent : AppTheme.primaryColor,
                          ),
                          onPressed: () {
                            if (isVideo) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => VideoDetailsScreen(
                                    course: widget.course,
                                    allCourseVideos: _videos,
                                    initialVideo: mat,
                                    courseResources: [..._notes, ..._assignments],
                                  ),
                                ),
                              );
                            } else if (mat.isPdf && mat.fileUrl != null) {
                              // Open PDF in-app
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PdfViewerScreen(
                                    url: mat.fileUrl!,
                                    title: mat.title,
                                  ),
                                ),
                              );
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
                                isVideo ? 'Watch' : 'Open',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
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
      },
    );
  }
}
