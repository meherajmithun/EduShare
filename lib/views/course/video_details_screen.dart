import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/models/video_comment_model.dart';
import 'package:edushare/models/material_rating_model.dart';
import 'package:edushare/models/contributor_profile_model.dart';
import 'package:edushare/views/profile/contributor_profile_screen.dart';
import 'package:edushare/widgets/glass_card.dart';
import 'package:edushare/widgets/material_rating_sheet.dart';
import 'package:edushare/widgets/pdf_viewer_screen.dart';
import 'package:edushare/widgets/save_to_folder_sheet.dart';
import 'package:intl/intl.dart';

class VideoDetailsScreen extends StatefulWidget {
  final CourseModel course;
  final List<MaterialModel> allCourseVideos;
  final MaterialModel initialVideo;
  final List<MaterialModel> courseResources; // Notes & Assignments

  const VideoDetailsScreen({
    Key? key,
    required this.course,
    required this.allCourseVideos,
    required this.initialVideo,
    this.courseResources = const [],
  }) : super(key: key);

  @override
  State<VideoDetailsScreen> createState() => _VideoDetailsScreenState();
}

class _VideoDetailsScreenState extends State<VideoDetailsScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;

  late MaterialModel _currentVideo;
  ContributorProfileModel? _contributorProfile;
  bool _isFollowing = false;
  bool _followingLoading = false;

  // ─── YouTube player ───────────────────────────────────────────────────
  YoutubePlayerController? _youtubeController;

  // ─── Native video player (Cloudinary) ────────────────────────────────
  VideoPlayerController? _nativeController;
  ChewieController? _chewieController;

  // ─── Player state ─────────────────────────────────────────────────────
  bool _playerInitializing = false;
  bool _playerError = false;
  String? _playerErrorMsg;
  bool _isPlaying = true;
  bool _isMuted = false;
  int _currentPosition = 0;
  int _totalDuration = 0;

  // Video progress state
  Map<String, Map<String, dynamic>> _progressMap = {}; // materialId -> {position, duration, completed}
  bool _isBookmarked = false;
  bool _autoPlayNext = true;
  int _viewsCount = 0;

  // Comments state
  List<VideoCommentModel> _comments = [];
  bool _loadingComments = false;
  final TextEditingController _commentController = TextEditingController();

  // Ratings state
  List<MaterialRatingModel> _ratings = [];
  bool _loadingRatings = false;

  Timer? _progressSaveTimer;
  Timer? _positionUpdateTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentVideo = widget.initialVideo;
    _viewsCount = _currentVideo.views;

    _initVideoPlayer(_currentVideo);
    _loadCourseProgress();
    _loadContributorProfile();
    _checkBookmark();
    _loadComments();
    _loadRatings();
    _incrementView();
    _recordInitialWatch();

    // Position updater for custom controls
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updatePlaybackState();
    });
  }

  void _updatePlaybackState() {
    if (!mounted) return;
    int pos = 0;
    int dur = 0;
    bool playing = false;

    if (_youtubeController != null) {
      pos = _youtubeController!.value.position.inSeconds;
      dur = _youtubeController!.metadata.duration.inSeconds;
      playing = _youtubeController!.value.isPlaying;
    } else if (_nativeController != null && _nativeController!.value.isInitialized) {
      pos = _nativeController!.value.position.inSeconds;
      dur = _nativeController!.value.duration.inSeconds;
      playing = _nativeController!.value.isPlaying;
    }

    if (pos != _currentPosition || dur != _totalDuration || playing != _isPlaying) {
      setState(() {
        _currentPosition = pos;
        if (dur > 0) _totalDuration = dur;
        _isPlaying = playing;
      });
    }
  }

  void _recordInitialWatch() async {
    final cId = widget.course.id.isNotEmpty
        ? widget.course.id
        : (_currentVideo.courseId.isNotEmpty ? _currentVideo.courseId : 'course');
    if (cId.isNotEmpty && _currentVideo.id.isNotEmpty) {
      final savedProg = _progressMap[_currentVideo.id];
      final startPos = (savedProg?['lastPosition'] as num?)?.toInt() ?? 0;
      final dur = (savedProg?['duration'] as num?)?.toInt() ?? 0;
      final isComp = savedProg?['completed'] == true;
      await _firestoreService.saveVideoProgress(
        materialId: _currentVideo.id,
        courseId: cId,
        lastPosition: startPos,
        duration: dur,
        completed: isComp,
      );
    }
  }

  void _incrementView() async {
    await _firestoreService.incrementVideoView(_currentVideo.id);
    if (mounted) {
      setState(() {
        _viewsCount++;
      });
    }
  }

  void _loadContributorProfile() async {
    if (_currentVideo.uploadedBy.isNotEmpty) {
      try {
        final prof = await _firestoreService.getContributorProfile(_currentVideo.uploadedBy);
        if (mounted) {
          setState(() {
            _contributorProfile = prof;
            _isFollowing = prof.isFollowing;
          });
        }
      } catch (_) {}
    }
  }

  void _toggleFollow() async {
    if (_currentVideo.uploadedBy.isEmpty || _followingLoading) return;
    setState(() => _followingLoading = true);
    final wasFollowing = _isFollowing;
    setState(() => _isFollowing = !wasFollowing);

    try {
      if (wasFollowing) {
        await _firestoreService.unfollowContributor(_currentVideo.uploadedBy);
      } else {
        await _firestoreService.followContributor(_currentVideo.uploadedBy);
      }
    } catch (_) {
      if (mounted) setState(() => _isFollowing = wasFollowing);
    } finally {
      if (mounted) setState(() => _followingLoading = false);
    }
  }

  // ─── Player initialisation ────────────────────────────────────────────

  void _initVideoPlayer(MaterialModel video) {
    _progressSaveTimer?.cancel();

    _disposeNativeController();
    _youtubeController?.removeListener(_onYoutubeStateChange);
    _youtubeController?.dispose();
    _youtubeController = null;

    setState(() {
      _playerInitializing = true;
      _playerError = false;
      _playerErrorMsg = null;
      _currentPosition = 0;
      _totalDuration = 0;
    });

    final savedProg = _progressMap[video.id];
    final startPos = (savedProg?['lastPosition'] as num?)?.toInt() ?? 0;

    if (video.isYouTube || video.isLegacyYouTube) {
      _initYouTubePlayer(video, startPos);
    } else if (video.isCloudinaryVideo) {
      _initNativePlayer(video, startPos);
    } else {
      setState(() {
        _playerInitializing = false;
        _playerError = true;
        _playerErrorMsg = 'This video has no playable source.';
      });
    }

    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveCurrentProgress();
    });
  }

  void _initYouTubePlayer(MaterialModel video, int startPos) {
    final url = video.isYouTube ? video.videoLink : video.videoPlaybackUrl;
    final videoId = YoutubePlayer.convertUrlToId(url ?? '');

    if (videoId == null || videoId.isEmpty) {
      setState(() {
        _playerInitializing = false;
        _playerError = true;
        _playerErrorMsg = 'Could not extract YouTube video ID.';
      });
      return;
    }

    _youtubeController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: _isMuted,
        startAt: startPos > 5 ? startPos - 2 : startPos,
        showLiveFullscreenButton: true,
      ),
    )..addListener(_onYoutubeStateChange);

    setState(() {
      _playerInitializing = false;
    });
  }

  void _initNativePlayer(MaterialModel video, int startPos) async {
    final url = video.fileUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        setState(() {
          _playerInitializing = false;
          _playerError = true;
          _playerErrorMsg = 'Video URL is missing. Please try again.';
        });
      }
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();

      if (startPos > 5) {
        await controller.seekTo(Duration(seconds: startPos - 2));
      }
      if (_isMuted) controller.setVolume(0);

      if (!mounted) {
        controller.dispose();
        return;
      }

      final chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: false, // We render our custom Figma-styled controls
        errorBuilder: (ctx, msg) => _buildPlayerErrorWidget(msg),
      );

      controller.addListener(() {
        if (controller.value.position >= controller.value.duration &&
            controller.value.duration.inSeconds > 0) {
          _saveCurrentProgress(forceCompleted: true);
          if (_autoPlayNext) {
            _playNextVideo();
          }
        }
      });

      setState(() {
        _nativeController = controller;
        _chewieController = chewieController;
        _playerInitializing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _playerInitializing = false;
          _playerError = true;
          _playerErrorMsg = 'Could not load video: ${e.toString()}';
        });
      }
    }
  }

  void _disposeNativeController() {
    _chewieController?.dispose();
    _chewieController = null;
    _nativeController?.dispose();
    _nativeController = null;
  }

  void _onYoutubeStateChange() {
    if (_youtubeController == null) return;
    final value = _youtubeController!.value;
    if (value.playerState == PlayerState.ended) {
      _saveCurrentProgress(forceCompleted: true);
      if (_autoPlayNext) {
        _playNextVideo();
      }
    }
  }

  // ─── Progress tracking ────────────────────────────────────────────────

  void _saveCurrentProgress({bool forceCompleted = false}) {
    if (!mounted) return;

    int pos = 0;
    int dur = 0;

    if (_youtubeController != null) {
      pos = _youtubeController!.value.position.inSeconds;
      dur = _youtubeController!.metadata.duration.inSeconds;
    } else if (_nativeController != null && _nativeController!.value.isInitialized) {
      pos = _nativeController!.value.position.inSeconds;
      dur = _nativeController!.value.duration.inSeconds;
    }

    if (pos <= 0 && dur <= 0) return;

    final isCompleted = forceCompleted ||
        (_progressMap[_currentVideo.id]?['completed'] == true) ||
        (dur > 0 && pos / dur >= 0.85);

    setState(() {
      _progressMap[_currentVideo.id] = {
        'lastPosition': pos,
        'duration': dur,
        'completed': isCompleted,
      };
    });

    final cId = widget.course.id.isNotEmpty
        ? widget.course.id
        : (_currentVideo.courseId.isNotEmpty ? _currentVideo.courseId : 'course');

    _firestoreService.saveVideoProgress(
      materialId: _currentVideo.id,
      courseId: cId,
      lastPosition: pos,
      duration: dur,
      completed: isCompleted,
    );
  }

  MaterialModel? _getNextVideo() {
    final index = widget.allCourseVideos.indexWhere((v) => v.id == _currentVideo.id);
    if (index != -1 && index < widget.allCourseVideos.length - 1) {
      return widget.allCourseVideos[index + 1];
    }
    // Fallback to first uncompleted video
    final uncompleted = widget.allCourseVideos.where((v) => _progressMap[v.id]?['completed'] != true && v.id != _currentVideo.id);
    if (uncompleted.isNotEmpty) {
      return uncompleted.first;
    }
    return null;
  }

  void _playNextVideo() {
    final next = _getNextVideo();
    if (next != null) {
      _switchVideo(next);
    }
  }

  void _switchVideo(MaterialModel nextVideo) {
    _saveCurrentProgress();

    setState(() {
      _currentVideo = nextVideo;
      _viewsCount = nextVideo.views;
    });

    _initVideoPlayer(nextVideo);
    _loadContributorProfile();
    _checkBookmark();
    _loadComments();
    _loadRatings();
    _incrementView();
    _recordInitialWatch();
  }

  void _togglePlayPause() {
    if (_youtubeController != null) {
      if (_isPlaying) {
        _youtubeController!.pause();
      } else {
        _youtubeController!.play();
      }
    } else if (_nativeController != null && _nativeController!.value.isInitialized) {
      if (_isPlaying) {
        _nativeController!.pause();
      } else {
        _nativeController!.play();
      }
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  void _toggleMute() {
    final newMute = !_isMuted;
    if (_youtubeController != null) {
      if (newMute) {
        _youtubeController!.mute();
      } else {
        _youtubeController!.unMute();
      }
    } else if (_nativeController != null) {
      _nativeController!.setVolume(newMute ? 0.0 : 1.0);
    }
    setState(() => _isMuted = newMute);
  }

  void _seekToPosition(double relativeFraction) {
    final dur = _totalDuration > 0 ? _totalDuration : 1;
    final targetSec = (dur * relativeFraction).toInt();
    if (_youtubeController != null) {
      _youtubeController!.seekTo(Duration(seconds: targetSec));
    } else if (_nativeController != null && _nativeController!.value.isInitialized) {
      _nativeController!.seekTo(Duration(seconds: targetSec));
    }
    setState(() => _currentPosition = targetSec);
  }

  // ─── Data loading ─────────────────────────────────────────────────────

  void _loadCourseProgress() async {
    final list = await _firestoreService.getCourseVideoProgress(widget.course.id);
    if (mounted) {
      final map = <String, Map<String, dynamic>>{};
      for (final item in list) {
        final matId = (item['materialId'] ?? '').toString();
        map[matId] = {
          'lastPosition': (item['lastPosition'] as num?)?.toInt() ?? 0,
          'duration': (item['duration'] as num?)?.toInt() ?? 0,
          'completed': item['completed'] as bool? ?? false,
        };
      }
      setState(() {
        _progressMap = map;
      });
    }
  }

  void _checkBookmark() async {
    final bookmarks = await _firestoreService.getBookmarks();
    if (mounted) {
      final isBkmk = bookmarks.any((b) =>
          (b['material']?['_id'] ?? b['material']?['id']) == _currentVideo.id);
      setState(() {
        _isBookmarked = isBkmk;
      });
    }
  }

  void _openSaveToFolderSheet() {
    SaveToFolderSheet.show(
      context,
      materialId: _currentVideo.id,
      courseId: widget.course.id,
      materialTitle: _currentVideo.title,
      onSaved: () {
        setState(() => _isBookmarked = true);
      },
    );
  }

  void _toggleBookmark() async {
    setState(() {
      _isBookmarked = !_isBookmarked;
    });
    if (_isBookmarked) {
      await _firestoreService.addBookmark(_currentVideo.id, widget.course.id);
    } else {
      await _firestoreService.removeBookmark(_currentVideo.id);
    }
  }

  void _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final data = await _firestoreService.getVideoComments(_currentVideo.id);
      if (mounted) {
        setState(() {
          _comments = data
              .map((e) => VideoCommentModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _loadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  void _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();
    try {
      final data = await _firestoreService.addVideoComment(_currentVideo.id, text);
      if (mounted) {
        setState(() {
          _comments.insert(0, VideoCommentModel.fromJson(data));
        });
      }
    } catch (_) {}
  }

  void _loadRatings() async {
    setState(() => _loadingRatings = true);
    try {
      final res = await _firestoreService.getMaterialRatings(_currentVideo.id);
      if (mounted) {
        setState(() {
          _ratings = (res['ratings'] as List<dynamic>? ?? [])
              .map((e) => MaterialRatingModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _loadingRatings = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRatings = false);
    }
  }

  void _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatViews(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M Views';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K Views';
    return '$count Views';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _saveCurrentProgress();
    _progressSaveTimer?.cancel();
    _positionUpdateTimer?.cancel();
    _youtubeController?.removeListener(_onYoutubeStateChange);
    _youtubeController?.dispose();
    _disposeNativeController();
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalVideos = widget.allCourseVideos.length;
    final completedCount = widget.allCourseVideos
        .where((v) => _progressMap[v.id]?['completed'] == true)
        .length;
    final progressPct = totalVideos > 0 ? (completedCount / totalVideos) : 0.0;
    final nextVideo = _getNextVideo();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ─── 1. Video Player Area with Custom Overlay Controls ──────
            _buildVideoPlayerArea(),

            // ─── 2. Scrollable Body: Metadata + Contributor + Tabs ───────
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + Bookmark Button Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    _currentVideo.title,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Save to Folder Button
                                GestureDetector(
                                  onTap: _openSaveToFolderSheet,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.bookmark_add_outlined,
                                        color: AppTheme.primaryColor,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Quick Bookmark Toggle
                                GestureDetector(
                                  onTap: _toggleBookmark,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                        color: _isBookmarked ? AppTheme.primaryColor : (isDark ? Colors.white70 : Colors.black54),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Views • Upload Date
                            Text(
                              '${_formatViews(_viewsCount)} • ${DateFormat('MMM d, yyyy').format(_currentVideo.createdAt)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Contributor Row with Follow Button
                            _buildContributorRow(isDark, theme),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // Tabs Header
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverTabBarDelegate(
                        TabBar(
                          controller: _tabController,
                          indicatorColor: AppTheme.primaryColor,
                          indicatorWeight: 3,
                          labelColor: AppTheme.primaryColor,
                          unselectedLabelColor: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          tabs: [
                            const Tab(text: 'Playlist'),
                            const Tab(text: 'Transcript'),
                            Tab(text: 'Comments (${_comments.length})'),
                            const Tab(text: 'Bookmarks'),
                          ],
                        ),
                        isDark: isDark,
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPlaylistTab(progressPct, completedCount, totalVideos, isDark, theme),
                    _buildTranscriptTab(isDark, theme),
                    _buildCommentsTab(isDark, theme),
                    _buildBookmarksTab(isDark, theme),
                  ],
                ),
              ),
            ),

            // ─── 3. Bottom Sticky Bar (UP NEXT / Continue) ──────────────
            _buildBottomStickyBar(nextVideo, isDark, theme),
          ],
        ),
      ),
    );
  }

  // ─── Video Player Area ────────────────────────────────────────────────

  Widget _buildVideoPlayerArea() {
    final curPosStr = _formatDuration(_currentPosition);
    final totDurStr = _formatDuration(_totalDuration);
    final progressFraction = _totalDuration > 0 ? (_currentPosition / _totalDuration).clamp(0.0, 1.0) : 0.0;

    return Container(
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video Surface
            Positioned.fill(child: _buildPlayerWidget()),

            // Gradient Overlays for controls visibility
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Top Bar: Back Button & 3-dots Menu
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 26),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showVideoOptionsMenu(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // Center Play / Pause Button
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ),

            // Bottom Controls Bar
            Positioned(
              left: 16,
              right: 16,
              bottom: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Blue scrubber slider
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (details) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box != null && box.size.width > 0) {
                        final rel = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                        _seekToPosition(rel);
                      }
                    },
                    onTapDown: (details) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box != null && box.size.width > 0) {
                        final rel = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                        _seekToPosition(rel);
                      }
                    },
                    child: SizedBox(
                      height: 18,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          // Background track
                          Container(
                            height: 4,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          // Played track
                          FractionallySizedBox(
                            widthFactor: progressFraction,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          // Scrubber handle
                          Align(
                            alignment: Alignment(progressFraction * 2 - 1, 0),
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Time and icons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$curPosStr / $totDurStr',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _toggleMute,
                            child: Icon(
                              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 22),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_special_rounded, color: AppTheme.primaryColor),
                title: const Text('Save to Folder', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openSaveToFolderSheet();
                },
              ),
              ListTile(
                leading: const Icon(Icons.star_outline_rounded, color: Colors.amber),
                title: const Text('Rate this Lecture', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  MaterialRatingSheet.show(context, _currentVideo, onRatingChanged: _loadRatings);
                },
              ),
              ListTile(
                leading: const Icon(Icons.replay_rounded, color: Colors.white70),
                title: const Text('Reload Video Player', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _initVideoPlayer(_currentVideo);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerWidget() {
    if (_playerInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }
    if (_playerError) {
      return _buildPlayerErrorWidget(_playerErrorMsg ?? 'Unknown error');
    }
    if (_youtubeController != null) {
      return YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: false,
      );
    }
    if (_chewieController != null) {
      return Chewie(controller: _chewieController!);
    }
    return _buildPlayerErrorWidget('No video player available.');
  }

  Widget _buildPlayerErrorWidget(String message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _initVideoPlayer(_currentVideo),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Contributor Row ──────────────────────────────────────────────────

  Widget _buildContributorRow(bool isDark, ThemeData theme) {
    final photo = _contributorProfile?.profilePhotoUrl ?? '';
    final name = _contributorProfile?.name.isNotEmpty == true
        ? _contributorProfile!.name
        : (_currentVideo.contributorName.isNotEmpty ? _currentVideo.contributorName : 'Instructor');
    final role = _contributorProfile?.designation.isNotEmpty == true
        ? _contributorProfile!.designation
        : (_contributorProfile?.bio.isNotEmpty == true
            ? _contributorProfile!.bio
            : '${widget.course.name.isNotEmpty ? widget.course.name : 'Course'} Instructor');

    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : 'IN';

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (_currentVideo.uploadedBy.isNotEmpty) {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ContributorProfileScreen(
                  contributorId: _currentVideo.uploadedBy,
                  contributorName: name,
                ),
              ));
            }
          },
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  image: photo.isNotEmpty
                      ? DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover)
                      : null,
                ),
                child: photo.isEmpty
                    ? Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    role,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        // Follow Button
        GestureDetector(
          onTap: _toggleFollow,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            decoration: BoxDecoration(
              color: _isFollowing ? AppTheme.primaryColor : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isFollowing ? AppTheme.primaryColor : const Color(0xFF334155),
              ),
            ),
            child: Text(
              _isFollowing ? 'Following' : 'Follow',
              style: TextStyle(
                color: _isFollowing ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── 1. Playlist Tab ───────────────────────────────────────────────────

  Widget _buildPlaylistTab(
    double progressPct,
    int completedCount,
    int totalVideos,
    bool isDark,
    ThemeData theme,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Course Progress Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2A) : AppTheme.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF223048) : AppTheme.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'COURSE PROGRESS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  Text(
                    '${(progressPct * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$completedCount of $totalVideos Videos Watched',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressPct,
                  minHeight: 5,
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.black.withOpacity(0.06),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Playlist items
        ...widget.allCourseVideos.map((video) {
          final isCurrent = video.id == _currentVideo.id;
          final isCompleted = _progressMap[video.id]?['completed'] == true;
          final savedPos = (_progressMap[video.id]?['lastPosition'] as num?)?.toInt() ?? 0;
          final dur = (_progressMap[video.id]?['duration'] as num?)?.toInt() ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => _switchVideo(video),
              child: Container(
                decoration: BoxDecoration(
                  color: isCurrent
                      ? (isDark ? const Color(0xFF132238) : AppTheme.primaryColor.withOpacity(0.08))
                      : (isDark ? const Color(0xFF111827) : AppTheme.lightCard),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCurrent
                        ? AppTheme.primaryColor
                        : (isDark ? const Color(0xFF1E293B) : AppTheme.lightBorder),
                    width: isCurrent ? 1.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Video Thumbnail with Overlay
                    Container(
                      width: 90,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/video_placeholder.png'),
                          fit: BoxFit.cover,
                          onError: _suppressImageError,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          if (isCompleted)
                            const Center(
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF10B981),
                                size: 26,
                              ),
                            )
                          else if (isCurrent)
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'PLAYING',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          if (!isCurrent && dur > 0)
                            Positioned(
                              bottom: 4,
                              right: 6,
                              child: Text(
                                _formatDuration(dur),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title & Progress
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? AppTheme.primaryColor
                                  : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isCompleted
                                ? 'Completed'
                                : (isCurrent
                                    ? '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}'
                                    : (savedPos > 0
                                        ? '${_formatDuration(savedPos)} watched'
                                        : 'Not started')),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  static void _suppressImageError(Object exception, StackTrace? stackTrace) {}

  // ─── 2. Transcript Tab ─────────────────────────────────────────────────

  Widget _buildTranscriptTab(bool isDark, ThemeData theme) {
    final transcript = _currentVideo.description.isNotEmpty
        ? _currentVideo.description
        : 'This lecture covers the foundational theory, algorithms, and practical applications for ${widget.course.name}.\n\nFollow along with the video slides and lecture notes attached in the Resources section.';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lecture Overview & Transcript',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                transcript,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 3. Comments Tab ───────────────────────────────────────────────────

  Widget _buildCommentsTab(bool isDark, ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: _loadingComments
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : _comments.isEmpty
                  ? Center(
                      child: Text(
                        'No comments yet. Start the discussion!',
                        style: TextStyle(
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final c = _comments[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                                backgroundImage: c.userPhoto.isNotEmpty
                                    ? NetworkImage(c.userPhoto)
                                    : null,
                                child: c.userPhoto.isEmpty
                                    ? Text(
                                        c.userName.isNotEmpty ? c.userName[0].toUpperCase() : 'S',
                                        style: const TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          c.userName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('MMM d, h:mm a').format(c.createdAt),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      c.comment,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
        // Comment input bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2A) : AppTheme.lightCard,
            border: Border(
              top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask a question or leave a comment...',
                    hintStyle: TextStyle(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      fontSize: 13,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppTheme.primaryColor),
                onPressed: _postComment,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 4. Bookmarks Tab ──────────────────────────────────────────────────

  Widget _buildBookmarksTab(bool isDark, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: _isBookmarked ? AppTheme.primaryColor : Colors.grey,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isBookmarked ? 'Video is Bookmarked' : 'Save for Later',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isBookmarked
                          ? 'This video is in your Saved Library for quick access.'
                          : 'Tap bookmark to save this video to your library.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _openSaveToFolderSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_special_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Folder', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton(
                    onPressed: _toggleBookmark,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      side: BorderSide(
                        color: _isBookmarked ? Colors.redAccent : AppTheme.primaryColor,
                      ),
                    ),
                    child: Text(
                      _isBookmarked ? 'Remove' : 'Bookmark',
                      style: TextStyle(
                        color: _isBookmarked ? Colors.redAccent : AppTheme.primaryColor,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Bottom Sticky Bar (UP NEXT / Continue) ───────────────────────────

  Widget _buildBottomStickyBar(MaterialModel? nextVideo, bool isDark, ThemeData theme) {
    final nextTitle = nextVideo?.title ?? 'Next Lecture';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : AppTheme.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'UP NEXT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nextTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () {
              if (nextVideo != null) {
                _switchVideo(nextVideo);
              }
            },
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
            label: const Text(
              'Continue',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDark;

  _SliverTabBarDelegate(this.tabBar, {required this.isDark});

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
