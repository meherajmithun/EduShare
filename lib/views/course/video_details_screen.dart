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
import 'package:edushare/views/profile/contributor_profile_screen.dart';
import 'package:edushare/widgets/glass_card.dart';
import 'package:edushare/widgets/material_rating_sheet.dart';
import 'package:edushare/widgets/pdf_viewer_screen.dart';
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

  // ─── YouTube player ───────────────────────────────────────────────────
  YoutubePlayerController? _youtubeController;

  // ─── Native video player (Cloudinary) ────────────────────────────────
  VideoPlayerController? _nativeController;
  ChewieController? _chewieController;

  // ─── Player state ─────────────────────────────────────────────────────
  bool _playerInitializing = false;
  bool _playerError = false;
  String? _playerErrorMsg;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentVideo = widget.initialVideo;
    _viewsCount = _currentVideo.views;

    _initVideoPlayer(_currentVideo);
    _loadCourseProgress();
    _checkBookmark();
    _loadComments();
    _loadRatings();
    _incrementView();
    _recordInitialWatch();
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

  // ─── Player initialisation ────────────────────────────────────────────

  void _initVideoPlayer(MaterialModel video) {
    _progressSaveTimer?.cancel();

    // Dispose previous controllers
    _disposeNativeController();
    _youtubeController?.removeListener(_onYoutubeStateChange);
    _youtubeController?.dispose();
    _youtubeController = null;

    setState(() {
      _playerInitializing = true;
      _playerError = false;
      _playerErrorMsg = null;
    });

    // Get last saved position
    final savedProg = _progressMap[video.id];
    final startPos = (savedProg?['lastPosition'] as num?)?.toInt() ?? 0;

    // ── Detect source ─────────────────────────────────────────────────
    if (video.isYouTube || video.isLegacyYouTube) {
      _initYouTubePlayer(video, startPos);
    } else if (video.isCloudinaryVideo) {
      _initNativePlayer(video, startPos);
    } else {
      // No valid playback URL
      setState(() {
        _playerInitializing = false;
        _playerError = true;
        _playerErrorMsg = 'This video has no playable source. The URL may be missing or invalid.';
      });
    }

    // Save progress every 5 seconds
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
        _playerErrorMsg = 'Could not extract YouTube video ID from the URL.';
      });
      return;
    }

    _youtubeController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        startAt: startPos > 5 ? startPos - 2 : startPos,
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

      // Seek to last saved position
      if (startPos > 5) {
        await controller.seekTo(Duration(seconds: startPos - 2));
      }

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
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.primaryColor,
          handleColor: AppTheme.primaryColor,
          backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
          bufferedColor: AppTheme.primaryColor.withOpacity(0.4),
        ),
        errorBuilder: (ctx, msg) => _buildPlayerErrorWidget(msg),
      );

      // Listen for end-of-video
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

  // ─── Player event handlers ────────────────────────────────────────────

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

  void _playNextVideo() {
    final index = widget.allCourseVideos.indexWhere((v) => v.id == _currentVideo.id);
    if (index != -1 && index < widget.allCourseVideos.length - 1) {
      _switchVideo(widget.allCourseVideos[index + 1]);
    }
  }

  void _switchVideo(MaterialModel nextVideo) {
    _saveCurrentProgress();

    setState(() {
      _currentVideo = nextVideo;
      _viewsCount = nextVideo.views;
    });

    _initVideoPlayer(nextVideo);
    _checkBookmark();
    _loadComments();
    _loadRatings();
    _incrementView();
    _recordInitialWatch();
  }

  void _retryPlayer() {
    _initVideoPlayer(_currentVideo);
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

  @override
  void dispose() {
    _saveCurrentProgress();
    _progressSaveTimer?.cancel();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.course.code,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
            color: _isBookmarked ? AppTheme.primaryColor : null,
            onPressed: _toggleBookmark,
            tooltip: _isBookmarked ? 'Remove Bookmark' : 'Bookmark Video',
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Video Player ─────────────────────────────────────────────
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _buildPlayerWidget(),
            ),
          ),

          // ─── Header + Tabs ────────────────────────────────────────────
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentVideo.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Views, Date, Rating
                          Row(
                            children: [
                              Icon(Icons.remove_red_eye_outlined, size: 14, color: theme.disabledColor),
                              const SizedBox(width: 4),
                              Text(
                                '$_viewsCount views',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: 12, color: theme.disabledColor),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.calendar_today_outlined, size: 14, color: theme.disabledColor),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('MMM dd, yyyy').format(_currentVideo.createdAt),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: 12, color: theme.disabledColor),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () {
                                  MaterialRatingSheet.show(
                                    context,
                                    _currentVideo,
                                    onRatingChanged: _loadRatings,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        _currentVideo.avgRating > 0
                                            ? _currentVideo.avgRating.toStringAsFixed(1)
                                            : 'Rate',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Contributor + Auto-play
                          Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  if (_currentVideo.uploadedBy.isNotEmpty) {
                                    Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => ContributorProfileScreen(
                                        contributorId: _currentVideo.uploadedBy,
                                        contributorName: _currentVideo.contributorName,
                                      ),
                                    ));
                                  }
                                },
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppTheme.primaryColor,
                                      child: Text(
                                        _currentVideo.contributorName.isNotEmpty
                                            ? _currentVideo.contributorName[0].toUpperCase()
                                            : 'C',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _currentVideo.contributorName,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Text(
                                    'Auto-play Next',
                                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                                  ),
                                  Switch(
                                    value: _autoPlayNext,
                                    onChanged: (val) => setState(() => _autoPlayNext = val),
                                    activeColor: AppTheme.primaryColor,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Description
                          if (_currentVideo.description.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _currentVideo.description,
                                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                              ),
                            ),
                          const SizedBox(height: 8),
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
                        labelColor: AppTheme.primaryColor,
                        unselectedLabelColor: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                        tabs: const [
                          Tab(text: 'Playlist'),
                          Tab(text: 'Comments'),
                          Tab(text: 'Reviews'),
                          Tab(text: 'Resources'),
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
                  _buildPlaylistTab(progressPct, completedCount, totalVideos),
                  _buildCommentsTab(),
                  _buildReviewsTab(),
                  _buildResourcesTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Player widget builder ────────────────────────────────────────────

  Widget _buildPlayerWidget() {
    // Loading state
    if (_playerInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            SizedBox(height: 12),
            Text(
              'Loading video...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Error state
    if (_playerError) {
      return _buildPlayerErrorWidget(_playerErrorMsg ?? 'Unknown error');
    }

    // YouTube player
    if (_youtubeController != null) {
      return YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppTheme.primaryColor,
      );
    }

    // Native (Cloudinary) player via Chewie
    if (_chewieController != null) {
      return Chewie(controller: _chewieController!);
    }

    // No player available
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
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Text(
                'Playback Error',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _retryPlayer,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 1. Playlist Tab ───────────────────────────────────────────────────
  Widget _buildPlaylistTab(double progressPct, int completedCount, int totalVideos) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Course Progress: $completedCount of $totalVideos completed',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    '${(progressPct * 100).toInt()}%',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressPct,
                  minHeight: 6,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: widget.allCourseVideos.length,
            itemBuilder: (context, index) {
              final video = widget.allCourseVideos[index];
              final isCurrent = video.id == _currentVideo.id;
              final isCompleted = _progressMap[video.id]?['completed'] == true;

              return Container(
                color: isCurrent
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : Colors.transparent,
                child: ListTile(
                  leading: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? Colors.green.withOpacity(0.15)
                              : (isCurrent
                                  ? AppTheme.primaryColor.withOpacity(0.2)
                                  : theme.dividerColor.withOpacity(0.1)),
                        ),
                        child: Icon(
                          isCompleted
                              ? Icons.check_circle_rounded
                              : (isCurrent
                                  ? Icons.play_arrow_rounded
                                  : Icons.video_library_outlined),
                          color: isCompleted
                              ? Colors.green
                              : (isCurrent ? AppTheme.primaryColor : theme.disabledColor),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    '${index + 1}. ${video.title}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? AppTheme.primaryColor : null,
                    ),
                  ),
                  subtitle: Text(
                    video.contributorName,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontSize: 11, color: theme.disabledColor),
                  ),
                  trailing: isCurrent
                      ? const Text(
                          'PLAYING',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                  onTap: () => _switchVideo(video),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── 2. Comments Tab ───────────────────────────────────────────────────
  Widget _buildCommentsTab() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: _loadingComments
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : _comments.isEmpty
                  ? Center(
                      child: Text(
                        'No comments yet. Start the discussion!',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final c = _comments[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppTheme.primaryColor,
                                backgroundImage: c.userPhoto.isNotEmpty
                                    ? NetworkImage(c.userPhoto)
                                    : null,
                                child: c.userPhoto.isEmpty
                                    ? Text(
                                        c.userName[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          c.userName,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('MMM d, h:mm a').format(c.createdAt),
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontSize: 10,
                                            color: theme.disabledColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      c.comment,
                                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: 'Ask a question or leave a comment...',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

  // ─── 3. Reviews Tab ────────────────────────────────────────────────────
  Widget _buildReviewsTab() {
    final theme = Theme.of(context);
    return _loadingRatings
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
        : _ratings.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_outline_rounded, size: 48, color: Colors.amber),
                    const SizedBox(height: 8),
                    Text('No reviews yet for this video.', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        MaterialRatingSheet.show(
                          context,
                          _currentVideo,
                          onRatingChanged: _loadRatings,
                        );
                      },
                      icon: const Icon(Icons.rate_review_rounded, size: 16),
                      label: const Text('Be the first to review'),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _ratings.length,
                itemBuilder: (context, index) {
                  final r = _ratings[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                r.ratedByName.isNotEmpty ? r.ratedByName : 'Student',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < r.stars
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: Colors.amber,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (r.review.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              r.review,
                              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
  }

  // ─── 4. Resources Tab ──────────────────────────────────────────────────
  Widget _buildResourcesTab() {
    final theme = Theme.of(context);
    final resources = widget.courseResources;

    return resources.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_rounded, size: 48, color: theme.disabledColor),
                const SizedBox(height: 8),
                Text(
                  'No additional slides or PDFs for this course.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: resources.length,
            itemBuilder: (context, index) {
              final mat = resources[index];
              final isPdf = mat.isPdf;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        isPdf
                            ? Icons.picture_as_pdf_rounded
                            : (mat.type == 'assignment'
                                ? Icons.task_rounded
                                : Icons.description_rounded),
                        color: isPdf ? Colors.redAccent : AppTheme.primaryColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mat.title,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${mat.type.toUpperCase()} • ${mat.contributorName}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 11,
                                color: theme.disabledColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () {
                          if (isPdf && mat.fileUrl != null) {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => PdfViewerScreen(
                                url: mat.fileUrl!,
                                title: mat.title,
                              ),
                            ));
                          } else {
                            _openUrl(mat.fileUrl);
                          }
                        },
                        child: const Text('Open', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              );
            },
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
