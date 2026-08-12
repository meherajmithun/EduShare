/// contributor_profile_screen.dart — Figma-matched Contributor Profile (Student View)
///
/// Layout:
///   - Custom AppBar: back | "CONTRIBUTOR PROFILE" | share button
///   - Profile header card: avatar + name + verified badge + status/dept + bio
///   - Follow button (student only, optimistic update)
///   - Stats row: Rating | Reviews | Uploads | Downloads | Followers | Following
///   - Tab Section: TOP RESOURCES | RECENT UPLOADS
///   - Resource cards: type icon + title + views + rating stars
///   - Rating/review dialog preserved from original

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/core/role_helper.dart';
import 'package:edushare/models/contributor_profile_model.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/models/rating_model.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/views/course/video_details_screen.dart';
import 'package:edushare/widgets/glass_card.dart';
import 'package:edushare/widgets/pdf_viewer_screen.dart';

class ContributorProfileScreen extends StatefulWidget {
  final String contributorId;
  final String? contributorName;

  const ContributorProfileScreen({
    Key? key,
    required this.contributorId,
    this.contributorName,
  }) : super(key: key);

  @override
  State<ContributorProfileScreen> createState() => _ContributorProfileScreenState();
}

class _ContributorProfileScreenState extends State<ContributorProfileScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _service = FirestoreService();

  bool _isLoading = true;
  ContributorProfileModel? _profile;
  List<MaterialModel> _materials = [];
  List<RatingModel> _ratings = [];
  RatingModel? _myRating;
  String? _errorMessage;
  bool _isFollowLoading = false;

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
    });

    try {
      final profile = await _service.getContributorProfile(widget.contributorId);
      final materials = await _service.getContributorMaterials(widget.contributorId);
      final ratingsData = await _service.getContributorRatings(widget.contributorId);

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
      // Roll back
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEditing ? 'Edit Your Review' : 'Rate this Contributor',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tap stars to select rating:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      try {
                        if (isEditing) {
                          await _service.updateRating(
                            widget.contributorId,
                            selectedStars,
                            review: reviewController.text,
                          );
                        } else {
                          await _service.addRating(
                            widget.contributorId,
                            selectedStars,
                            review: reviewController.text,
                          );
                        }
                        if (context.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.primaryColor,
                              content: Text(isEditing
                                  ? 'Rating updated successfully!'
                                  : 'Rating submitted successfully!'),
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
                              content: Text(e.toString().replaceAll('Exception: ', '')),
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(isEditing ? 'Update' : 'Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRating() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Rating'),
        content: const Text('Are you sure you want to remove your rating for this contributor?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
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

  // ── Material action launcher ───────────────────────────────────────────────
  Future<void> _launchMaterial(MaterialModel m) async {
    if (m.type == 'video' || m.videoPlaybackUrl != null || m.isYouTube || m.isCloudinaryVideo) {
      final course = CourseModel(
        id: m.courseId.isNotEmpty ? m.courseId : 'general',
        name: m.department.isNotEmpty ? m.department : 'Academic Video',
        code: 'VIDEO',
        departmentId: m.departmentId.isNotEmpty ? m.departmentId : 'dept',
      );
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoDetailsScreen(
              course: course,
              allCourseVideos: [m],
              initialVideo: m,
            ),
          ),
        );
      }
    } else if (m.isPdf && m.fileUrl != null && m.fileUrl!.isNotEmpty) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              url: m.fileUrl!,
              title: m.title,
            ),
          ),
        );
      }
    } else if (m.fileUrl != null && m.fileUrl!.isNotEmpty) {
      final uri = Uri.parse(m.fileUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = context.read<AuthService>().currentUser;
    final isStudent = currentUser?.isStudent ?? false;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _errorMessage != null
              ? _buildError(theme)
              : _buildContent(theme, currentUser, isStudent, isDark),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contributor Profile'),
        leading: const BackButton(),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'Something went wrong',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadProfileData, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      ThemeData theme, UserModel? currentUser, bool isStudent, bool isDark) {
    final profile = _profile!;

    final topResources = [..._materials]
      ..sort((a, b) => b.views.compareTo(a.views));
    final recentUploads = [..._materials]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Custom AppBar ─────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                        ),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'CONTRIBUTOR PROFILE',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                        ),
                      ),
                      child: const Icon(Icons.share_rounded, size: 18),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: 'Check out ${profile.name}\'s profile on EduShare!',
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile link copied!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Profile Hero Header Card ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with checkmark badge + Follow button on top right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar with verified badge
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
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF3B82F6),
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Follow & Rate buttons
                      Row(
                        children: [
                          if (isStudent) ...[
                            _FollowButton(
                              isFollowing: profile.isFollowing,
                              isLoading: _isFollowLoading,
                              onTap: _toggleFollow,
                            ),
                            const SizedBox(width: 8),
                          ],
                          _RateButton(
                            myRating: _myRating,
                            isStudent: isStudent,
                            onTap: () => _showRatingDialog(
                                isEditing: _myRating != null),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Name + PRO badge
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Department / University subtitle
                  Row(
                    children: [
                      const Icon(Icons.account_balance_rounded,
                          size: 14, color: AppTheme.primaryColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          profile.department.isNotEmpty
                              ? profile.department
                              : 'Dept. of Computer Science',
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
                  if (profile.bio.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      profile.bio,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Rating Summary Glass Card ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Large Score
                  Text(
                    profile.avgRating.toStringAsFixed(1),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Stars + Label
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < profile.avgRating.floor()
                                ? Icons.star_rounded
                                : (i < profile.avgRating
                                    ? Icons.star_half_rounded
                                    : Icons.star_outline_rounded),
                            color: const Color(0xFFF59E0B),
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Average Rating',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 10,
                          color: theme.disabledColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Divider
                  Container(height: 36, width: 1, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  const SizedBox(width: 12),
                  // Description
                  Expanded(
                    child: Text(
                      'Based on ${profile.totalRatings} student reviews across all uploaded study materials.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── 4 Stats Row ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Uploads',
                    value: '${profile.approvedUploads}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: 'Downloads',
                    value: _formatCount(profile.totalDownloads),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: 'Followers',
                    value: _formatCount(profile.followerCount),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: 'Following',
                    value: '${profile.followingCount}',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── TOP RESOURCES ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'TOP RESOURCES',
                      style: theme.textTheme.labelLarge?.copyWith(
                        letterSpacing: 1.2,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  'View All',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (topResources.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'No approved resources yet.',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: topResources.take(6).length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _TopResourceCard(
                  material: topResources[i],
                  onTap: () => _launchMaterial(topResources[i]),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // ── RECENT UPLOADS ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'RECENT UPLOADS',
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1.2,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (recentUploads.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'No resources uploaded yet.',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recentUploads.take(6).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _MaterialCard(
                material: recentUploads[i],
                onTap: () => _launchMaterial(recentUploads[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ContributorProfileModel profile) {
    final initials = profile.name.isNotEmpty
        ? profile.name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : 'C';
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        image: profile.profilePhotoUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(profile.profilePhotoUrl),
                fit: BoxFit.cover,
                onError: (_, __) {},
              )
            : null,
      ),
      child: profile.profilePhotoUrl.isEmpty
          ? Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            )
          : null,
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─── Metric Card ─────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 10,
              color: theme.disabledColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Top Resource Card ────────────────────────────────────────────────────────
class _TopResourceCard extends StatelessWidget {
  final MaterialModel material;
  final VoidCallback onTap;

  const _TopResourceCard({required this.material, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
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
            // Cover Thumbnail Box + Badges & Overlay
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background Cover Image
                    Image.network(
                      material.computedThumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.4),
                              AppTheme.primaryDark.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    // Dark Gradient Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.2),
                            Colors.black.withOpacity(0.6),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    // Center Play / Document Button
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          material.type == 'video'
                              ? Icons.play_arrow_rounded
                              : Icons.description_rounded,
                          color: Colors.white,
                          size: material.type == 'video' ? 24 : 20,
                        ),
                      ),
                    ),
                    // Material Type Badge
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
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              material.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // Footer: views + rating
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.download_rounded,
                        size: 11, color: AppTheme.darkTextSecondary),
                    const SizedBox(width: 2),
                    Text(
                      _formatCount(material.views),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 11, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 2),
                    Text(
                      material.avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF59E0B),
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

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isFollowing
              ? Colors.transparent
              : AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFollowing ? AppTheme.primaryColor : Colors.transparent,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFollowing
                        ? Icons.person_remove_outlined
                        : Icons.person_add_rounded,
                    size: 14,
                    color: isFollowing ? AppTheme.primaryColor : Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: TextStyle(
                      color: isFollowing ? AppTheme.primaryColor : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
            const SizedBox(width: 4),
            Text(
              myRating != null ? 'Edit Rating' : 'Rate',
              style: const TextStyle(
                color: Color(0xFFF59E0B),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Material Card ────────────────────────────────────────────────────────────
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
            // Cover Image Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      material.computedThumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: _typeColor.withOpacity(0.12),
                        child: Icon(_typeIcon, color: _typeColor, size: 22),
                      ),
                    ),
                    if (material.type == 'video')
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: const Center(
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Title + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      material.type.toUpperCase(),
                      style: TextStyle(
                        color: _typeColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    material.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.remove_red_eye_rounded,
                          size: 12, color: theme.disabledColor),
                      const SizedBox(width: 3),
                      Text(
                        '${material.views}',
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.star_rounded,
                          size: 12, color: const Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text(
                        material.avgRating.toStringAsFixed(1),
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: theme.disabledColor),
          ],
        ),
      ),
    );
  }
}
