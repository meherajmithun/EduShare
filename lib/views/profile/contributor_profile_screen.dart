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
import 'package:edushare/models/material_model.dart';
import 'package:edushare/models/rating_model.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/widgets/glass_card.dart';

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
    if (m.type == 'video') {
      if (m.videoLink != null) {
        final uri = Uri.parse(m.videoLink!);
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else if (m.fileUrl != null && m.fileUrl!.isNotEmpty) {
      final uri = Uri.parse(m.fileUrl!);
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
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

    // Sorted materials for each tab
    final topResources = [..._materials]
      ..sort((a, b) => b.views.compareTo(a.views));
    final recentUploads = [..._materials]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxScrolled) => [
        SliverToBoxAdapter(
          child: Column(
            children: [
              // ── Custom AppBar ─────────────────────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'CONTRIBUTOR PROFILE',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 10,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            Text(
                              profile.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Share button
                      IconButton(
                        icon: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                            shape: BoxShape.circle,
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

              // ── Profile Header Card ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Avatar + follow
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAvatar(profile),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name + verified badge
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        profile.name,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (profile.isVerified) ...[
                                      const SizedBox(width: 6),
                                      const _VerifiedBadge(),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Designation or department
                                Text(
                                  profile.designation.isNotEmpty
                                      ? profile.designation
                                      : profile.department,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                // Follow / Rate buttons
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
                          ),
                        ],
                      ),

                      // Bio
                      if (profile.bio.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            profile.bio,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Stats Row ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatCell(
                        label: 'Rating',
                        value: profile.avgRating.toStringAsFixed(1),
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFFF59E0B),
                      ),
                      _vDivider(),
                      _StatCell(
                          label: 'Reviews', value: '${profile.totalRatings}'),
                      _vDivider(),
                      _StatCell(
                          label: 'Uploads', value: '${profile.approvedUploads}'),
                      _vDivider(),
                      _StatCell(
                        label: 'Downloads',
                        value: _formatCount(profile.totalDownloads),
                      ),
                      _vDivider(),
                      _StatCell(
                          label: 'Followers', value: '${profile.followerCount}'),
                      _vDivider(),
                      _StatCell(
                          label: 'Following', value: '${profile.followingCount}'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Tab Bar ───────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: theme.textTheme.bodyMedium?.color,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                  indicator: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    const Tab(text: 'TOP RESOURCES'),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'RECENT UPLOADS',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          if (_ratings.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_ratings.length}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 9),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── TOP RESOURCES ─────────────────────────────────────────────
          _MaterialList(
            materials: topResources.take(8).toList(),
            emptyMessage: 'No approved resources yet.',
            onTap: _launchMaterial,
          ),
          // ── RECENT UPLOADS ────────────────────────────────────────────
          _MaterialList(
            materials: recentUploads.take(10).toList(),
            emptyMessage: 'No resources uploaded yet.',
            onTap: _launchMaterial,
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

  Widget _vDivider() {
    return Container(height: 28, width: 1, color: AppTheme.darkBorder);
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─── Verified Badge ───────────────────────────────────────────────────────────
class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Verified Contributor (≥4.0 rating)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, color: Colors.white, size: 10),
            SizedBox(width: 2),
            Text(
              'VERIFIED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
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
    required this.myRating,
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

// ─── Stat Cell ────────────────────────────────────────────────────────────────
class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;

  const _StatCell({
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 2),
            ],
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
        ),
      ],
    );
  }
}

// ─── Material List (Scrollable) ───────────────────────────────────────────────
class _MaterialList extends StatelessWidget {
  final List<MaterialModel> materials;
  final String emptyMessage;
  final Future<void> Function(MaterialModel) onTap;

  const _MaterialList({
    required this.materials,
    required this.emptyMessage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open_rounded,
                  size: 48, color: Theme.of(context).disabledColor),
              const SizedBox(height: 12),
              Text(emptyMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: materials.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _MaterialCard(
        material: materials[i],
        onTap: () => onTap(materials[i]),
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
            // Type icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _typeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_typeIcon, color: _typeColor, size: 22),
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
