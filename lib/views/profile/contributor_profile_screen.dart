/// contributor_profile_screen.dart — Figma-matched Contributor Profile (Student View)
///
/// Improvements over previous version:
///   1. Department security guard: students blocked from other-dept profiles
///   2. Gradient hero profile card (Figma dark style)
///   3. Pill-style TabBar for Top Resources / Recent Uploads
///   4. RefreshIndicator (pull-to-refresh)
///   5. My Rating chip with edit shortcut
///   6. Gradient thumbnail fallbacks — no Unsplash stock images
///   7. Fixed list separator axis (was width:10, now height:10)
///   8. Formatted upload dates on material cards
///   9. Icon+text empty states (no plain text)
///  10. Metric cards include icons

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/contributor_profile_model.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/models/rating_model.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/views/course/video_details_screen.dart';
import 'package:edushare/widgets/pdf_viewer_screen.dart';
import 'package:edushare/widgets/image_viewer_screen.dart';

class ContributorProfileScreen extends StatefulWidget {
  final String contributorId;
  final String? contributorName;

  const ContributorProfileScreen({
    Key? key,
    required this.contributorId,
    this.contributorName,
  }) : super(key: key);

  @override
  State<ContributorProfileScreen> createState() =>
      _ContributorProfileScreenState();
}

class _ContributorProfileScreenState extends State<ContributorProfileScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _service = FirestoreService();

  bool _isLoading = true;
  ContributorProfileModel? _profile;
  List<MaterialModel> _materials = [];
  List<RatingModel> _ratings = [];  // Populated on load; may be used in a future Reviews tab
  RatingModel? _myRating;
  String? _errorMessage;
  bool _isFollowLoading = false;
  bool _accessDenied = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _accessDenied = false;
    });

    try {
      final profile = await _service.getContributorProfile(widget.contributorId);

      // ── Department Security Guard ─────────────────────────────────────
      // Students may only view contributors from their own department.
      // Cache context-dependent values before the await gap.
      final currentUser = mounted ? context.read<AuthService>().currentUser : null;
      if (currentUser != null && currentUser.role == 'student') {
        final studentDeptId = currentUser.departmentId ?? '';
        final contribDeptId = profile.departmentId ?? '';
        if (studentDeptId.isNotEmpty &&
            contribDeptId.isNotEmpty &&
            studentDeptId != contribDeptId) {
          if (mounted) {
            setState(() {
              _profile = profile;
              _accessDenied = true;
              _isLoading = false;
            });
          }
          return;
        }
      }

      final results = await Future.wait([
        _service.getContributorMaterials(widget.contributorId),
        _service.getContributorRatings(widget.contributorId),
      ]);

      final materials = results[0] as List<MaterialModel>;
      final ratingsData = results[1] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _profile = profile;
          _materials = materials;
          _ratings = ratingsData['ratings'] as List<RatingModel>;
          _myRating = ratingsData['myRating'] as RatingModel?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null) return;
    setState(() => _isFollowLoading = true);
    final wasFollowing = _profile!.isFollowing;
    // Optimistic update
    setState(() {
      _profile = _profile!.copyWith(
        isFollowing: !wasFollowing,
        followerCount: _profile!.followerCount + (wasFollowing ? -1 : 1),
      );
    });

    try {
      if (wasFollowing) {
        await _service.unfollowContributor(widget.contributorId);
      } else {
        await _service.followContributor(widget.contributorId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _profile = _profile!.copyWith(
            isFollowing: wasFollowing,
            followerCount: _profile!.followerCount + (wasFollowing ? 1 : -1),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  void _showRatingDialog({bool isEditing = false}) {
    int selectedStars = _myRating?.stars ?? 5;
    final reviewController = TextEditingController(text: _myRating?.review ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkSurface
              : AppTheme.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEditing ? 'Edit Your Review' : 'Rate this Contributor',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tap stars to select rating:',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starValue = index + 1;
                    return IconButton(
                      onPressed: isSubmitting
                          ? null
                          : () => setDialogState(() => selectedStars = starValue),
                      icon: Icon(
                        starValue <= selectedStars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 36,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reviewController,
                  maxLines: 3,
                  maxLength: 500,
                  enabled: !isSubmitting,
                  decoration: InputDecoration(
                    hintText: 'Write an optional review...',
                    hintStyle: const TextStyle(fontSize: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            if (isEditing && _myRating != null)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                onPressed: isSubmitting
                    ? null
                    : () {
                        Navigator.of(ctx).pop();
                        _deleteRating();
                      },
                child: const Text('Remove'),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      try {
                        if (isEditing) {
                          await _service.updateRating(widget.contributorId,
                              selectedStars, review: reviewController.text);
                        } else {
                          await _service.addRating(widget.contributorId,
                              selectedStars, review: reviewController.text);
                        }
                        if (context.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.primaryColor,
                              content: Text(isEditing
                                  ? 'Rating updated!'
                                  : 'Rating submitted!'),
                            ),
                          );
                          _loadProfileData();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setDialogState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFFEF4444),
                              content: Text(
                                  e.toString().replaceAll('Exception: ', '')),
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(isEditing ? 'Update' : 'Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRating() async {
    try {
      await _service.deleteRating(widget.contributorId);
      _loadProfileData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _launchMaterial(MaterialModel m) async {
    if (m.type == 'video' ||
        m.videoPlaybackUrl != null ||
        m.isYouTube ||
        m.isCloudinaryVideo) {
      final course = CourseModel(
        id: m.courseId.isNotEmpty ? m.courseId : 'general',
        name: m.department.isNotEmpty ? m.department : 'Academic Video',
        code: 'VIDEO',
        departmentId: m.departmentId.isNotEmpty ? m.departmentId : 'dept',
      );
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VideoDetailsScreen(
            course: course,
            allCourseVideos: [m],
            initialVideo: m,
          ),
        ));
      }
    } else if (m.fileUrl != null && m.fileUrl!.isNotEmpty) {
      if (mounted) {
        if (m.isImage) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ImageViewerScreen(
              url: m.fileUrl!,
              title: m.title,
              materialId: m.id,
              courseName: m.department,
              contributorName: m.contributorName,
              createdAt: m.createdAt,
              courseId: m.courseId,
            ),
          ));
        } else {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              url: m.fileUrl!,
              title: m.title,
              materialId: m.id,
              courseName: m.department,
              contributorName: m.contributorName,
              createdAt: m.createdAt,
              courseId: m.courseId,
            ),
          ));
        }
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = context.read<AuthService>().currentUser;
    final isStudent = currentUser?.role == 'student';

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(isDark, null),
              const Expanded(
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryColor)),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) return _buildError(theme);
    if (_accessDenied) return _buildAccessDenied(theme, isDark);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: _loadProfileData,
          child: _buildContent(theme, currentUser, isStudent, isDark),
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contributor Profile')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 56, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text(_errorMessage ?? 'Something went wrong',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadProfileData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessDenied(ThemeData theme, bool isDark) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(isDark, _profile),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_outline_rounded,
                            size: 52, color: Color(0xFFEF4444)),
                      ),
                      const SizedBox(height: 24),
                      Text('Access Restricted',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(
                        'You can only view contributors from your own department.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (_profile != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'This contributor is from ${_profile!.department}.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Go Back'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark, ContributorProfileModel? profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            isDark: isDark,
            onTap: () => Navigator.of(context).pop(),
          ),
          Column(
            children: [
              const Text(
                'CONTRIBUTOR PROFILE',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              if (profile != null)
                Text(
                  profile.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          _CircleIconButton(
            icon: Icons.share_rounded,
            isDark: isDark,
            onTap: () {
              if (profile == null) return;
              Clipboard.setData(ClipboardData(
                  text:
                      "Check out ${profile.name}'s profile on EduShare!"));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile link copied!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    UserModel? currentUser,
    bool isStudent,
    bool isDark,
  ) {
    final profile = _profile!;

    final topResources = [..._materials]
      ..sort((a, b) => b.views.compareTo(a.views));
    final recentUploads = [..._materials]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return CustomScrollView(
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAppBar(isDark, profile),
              const SizedBox(height: 16),

              // Profile Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child:
                    _buildProfileCard(profile, isStudent, isDark, theme),
              ),
              const SizedBox(height: 14),

              // Rating Summary Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildRatingCard(profile, isDark, theme),
              ),

              // My Rating chip
              if (_myRating != null && isStudent) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildMyRatingChip(_myRating!, isDark, theme),
                ),
              ],

              const SizedBox(height: 14),

              // 4 Metric Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Uploads',
                        value: '${profile.approvedUploads}',
                        icon: Icons.upload_rounded,
                        iconColor: AppTheme.primaryColor,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCard(
                        label: 'Downloads',
                        value: _fmt(profile.totalDownloads),
                        icon: Icons.download_rounded,
                        iconColor: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCard(
                        label: 'Followers',
                        value: _fmt(profile.followerCount),
                        icon: Icons.people_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCard(
                        label: 'Following',
                        value: '${profile.followingCount}',
                        icon: Icons.person_add_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Pill Tab Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isDark
                            ? AppTheme.darkBorder
                            : AppTheme.lightBorder),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 11),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 11),
                    onTap: (_) => setState(() {}),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.star_rounded, size: 13),
                            SizedBox(width: 5),
                            Text('TOP RESOURCES'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload_file_rounded, size: 13),
                            SizedBox(width: 5),
                            Text('RECENT UPLOADS'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tab Contents
              if (_tabController.index == 0)
                _buildTopResources(topResources, theme, isDark)
              else
                _buildRecentUploads(recentUploads, theme, isDark),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(
    ContributorProfileModel profile,
    bool isStudent,
    bool isDark,
    ThemeData theme,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark ? const Color(0xFF1E293B) : AppTheme.lightSurface,
            AppTheme.primaryDark.withOpacity(isDark ? 0.7 : 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _buildAvatar(profile),
                  if (profile.isVerified)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF3B82F6), size: 18),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.account_balance_rounded,
                            size: 12, color: AppTheme.primaryColor),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            profile.department.isNotEmpty
                                ? profile.department
                                : 'Department',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (profile.designation.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.designation,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Row(
            children: [
              if (isStudent) ...[
                Expanded(
                  child: _FollowButton(
                    isFollowing: profile.isFollowing,
                    isLoading: _isFollowLoading,
                    onTap: _toggleFollow,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: _RateButton(
                  myRating: _myRating,
                  isStudent: isStudent,
                  onTap: () => _showRatingDialog(isEditing: _myRating != null),
                ),
              ),
            ],
          ),

          if (profile.bio.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              profile.bio,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontSize: 12, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingCard(
      ContributorProfileModel profile, bool isDark, ThemeData theme) {
    final avg = profile.avgRating;
    final count = profile.totalRatings;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            avg > 0 ? avg.toStringAsFixed(1) : '—',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 36,
              color: isDark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < avg.floor()
                          ? Icons.star_rounded
                          : (i < avg
                              ? Icons.star_half_rounded
                              : Icons.star_outline_rounded),
                      color: const Color(0xFFF59E0B),
                      size: 18,
                    );
                  }),
                ),
                const SizedBox(height: 3),
                Text(
                  count == 0
                      ? 'No reviews yet'
                      : '$count ${count == 1 ? 'review' : 'reviews'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
              width: 1,
              height: 38,
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              count == 0
                  ? 'No ratings yet. Be the first to rate!'
                  : 'Based on $count student ratings.',
              style: TextStyle(
                fontSize: 10,
                height: 1.4,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRatingChip(
      RatingModel rating, bool isDark, ThemeData theme) {
    return GestureDetector(
      onTap: () => _showRatingDialog(isEditing: true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(
              5,
              (i) => Icon(
                i < rating.stars
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: const Color(0xFFF59E0B),
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Your rating',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.edit_rounded,
                size: 12, color: Color(0xFFF59E0B)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopResources(
      List<MaterialModel> materials, ThemeData theme, bool isDark) {
    if (materials.isEmpty) {
      return _buildEmptyState(
        icon: Icons.star_border_rounded,
        label: 'No top resources yet',
        subtitle: 'Highly viewed materials will appear here.',
        isDark: isDark,
        theme: theme,
      );
    }
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: materials.take(8).length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _TopResourceCard(
          material: materials[i],
          onTap: () => _launchMaterial(materials[i]),
        ),
      ),
    );
  }

  Widget _buildRecentUploads(
      List<MaterialModel> materials, ThemeData theme, bool isDark) {
    if (materials.isEmpty) {
      return _buildEmptyState(
        icon: Icons.upload_file_outlined,
        label: 'No uploads yet',
        subtitle: 'Approved materials will appear here after review.',
        isDark: isDark,
        theme: theme,
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: materials.take(10).length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _MaterialCard(
        material: materials[i],
        onTap: () => _launchMaterial(materials[i]),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isDark,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 36,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary),
            const SizedBox(height: 10),
            Text(label,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ContributorProfileModel profile) {
    final initials = profile.name.isNotEmpty
        ? profile.name
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : 'C';
    final hasPhoto = profile.profilePhotoUrl.isNotEmpty;

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasPhoto
            ? null
            : const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(color: AppTheme.primaryColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: hasPhoto
          ? ClipOval(
              child: Image.network(
                profile.profilePhotoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22)),
                ),
              ),
            )
          : Center(
              child: Text(initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22))),
    );
  }

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─── Circle Icon Button ───────────────────────────────────────────────────────
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
          shape: BoxShape.circle,
          border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        ),
        child: Icon(icon,
            size: 16,
            color: isDark
                ? AppTheme.darkTextPrimary
                : AppTheme.lightTextPrimary),
      ),
    );
  }
}

// ─── Metric Card ──────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final bool isDark;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Follow Button ────────────────────────────────────────────────────────────
class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onTap;

  const _FollowButton({
    required this.isFollowing,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isFollowing ? Colors.transparent : AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color:
                  isFollowing ? AppTheme.primaryColor : Colors.transparent),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryColor, strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFollowing
                          ? Icons.person_remove_outlined
                          : Icons.person_add_rounded,
                      size: 14,
                      color: isFollowing
                          ? AppTheme.primaryColor
                          : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isFollowing ? 'Following' : 'Follow',
                      style: TextStyle(
                        color: isFollowing
                            ? AppTheme.primaryColor
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Rate Button ──────────────────────────────────────────────────────────────
class _RateButton extends StatelessWidget {
  final RatingModel? myRating;
  final bool isStudent;
  final VoidCallback onTap;

  const _RateButton({
    this.myRating,
    required this.isStudent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isStudent) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded,
                  size: 14, color: Color(0xFFF59E0B)),
              const SizedBox(width: 5),
              Text(
                myRating != null ? 'Edit Rating' : 'Rate',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Top Resource Card (horizontal scroll) ────────────────────────────────────
class _TopResourceCard extends StatelessWidget {
  final MaterialModel material;
  final VoidCallback onTap;

  const _TopResourceCard({required this.material, required this.onTap});

  static const Map<String, List<Color>> _typeGradients = {
    'video': [Color(0xFFEF4444), Color(0xFF7F1D1D)],
    'pdf': [Color(0xFFF59E0B), Color(0xFF78350F)],
    'notes': [Color(0xFF6366F1), Color(0xFF312E81)],
    'assignment': [Color(0xFF10B981), Color(0xFF064E3B)],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradientColors =
        _typeGradients[material.type] ?? _typeGradients['notes']!;

    final rawThumb = material.computedThumbnailUrl;
    final isRealThumb = rawThumb.contains('cloudinary.com') ||
        rawThumb.contains('img.youtube.com');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
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
                    if (isRealThumb)
                      Image.network(
                        rawThumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _gradientBox(gradientColors),
                      )
                    else
                      _gradientBox(gradientColors),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.5),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_iconFor(material.type),
                            color: Colors.white, size: 22),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: gradientColors.first,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          material.type.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold),
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
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.remove_red_eye_rounded,
                        size: 11, color: AppTheme.darkTextSecondary),
                    const SizedBox(width: 2),
                    Text(_fmt(material.views),
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.darkTextSecondary)),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 11, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 2),
                    Text(
                      material.avgRating > 0
                          ? material.avgRating.toStringAsFixed(1)
                          : '—',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF59E0B)),
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

  Widget _gradientBox(List<Color> colors) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );

  static IconData _iconFor(String type) {
    switch (type) {
      case 'video':
        return Icons.play_arrow_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'assignment':
        return Icons.assignment_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─── Material List Card ───────────────────────────────────────────────────────
class _MaterialCard extends StatelessWidget {
  final MaterialModel material;
  final VoidCallback onTap;

  const _MaterialCard({required this.material, required this.onTap});

  IconData get _typeIcon {
    switch (material.type) {
      case 'video':
        return Icons.play_circle_fill_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'assignment':
        return Icons.assignment_rounded;
      default:
        return Icons.article_rounded;
    }
  }

  Color get _typeColor {
    switch (material.type) {
      case 'video':
        return const Color(0xFFEF4444);
      case 'pdf':
        return const Color(0xFFF59E0B);
      case 'assignment':
        return AppTheme.primaryColor;
      default:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final rawThumb = material.computedThumbnailUrl;
    final isRealThumb = rawThumb.contains('cloudinary.com') ||
        rawThumb.contains('img.youtube.com');
    final dateStr = DateFormat('MMM d, yyyy').format(material.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 52,
                child: isRealThumb
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(rawThumb,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _iconFallback()),
                          if (material.type == 'video')
                            Container(
                              color: Colors.black.withOpacity(0.3),
                              child: const Center(
                                child: Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                        ],
                      )
                    : _iconFallback(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _typeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      material.type.toUpperCase(),
                      style: TextStyle(
                          color: _typeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    material.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 10,
                    children: [
                      _StatChip(
                          icon: Icons.calendar_today_rounded,
                          label: dateStr),
                      _StatChip(
                          icon: Icons.remove_red_eye_rounded,
                          label: _fmt(material.views)),
                      _StatChip(
                        icon: Icons.star_rounded,
                        label: material.avgRating > 0
                            ? material.avgRating.toStringAsFixed(1)
                            : '—',
                        iconColor: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary),
          ],
        ),
      ),
    );
  }

  Widget _iconFallback() => Container(
        color: _typeColor.withOpacity(0.12),
        child: Center(child: Icon(_typeIcon, color: _typeColor, size: 24)),
      );

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─── Stat Chip ────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;

  const _StatChip({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = iconColor ??
        (isDark
            ? AppTheme.darkTextSecondary
            : AppTheme.lightTextSecondary);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}
