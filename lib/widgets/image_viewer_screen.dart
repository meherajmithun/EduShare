import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/widgets/save_to_folder_sheet.dart';
import 'package:intl/intl.dart';

/// In-app interactive image viewer matching the Video Player dark sleek visual style.
class ImageViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  final String? materialId;
  final String? courseName;
  final String? contributorName;
  final String? contributorPhoto;
  final DateTime? createdAt;
  final String? courseId;

  const ImageViewerScreen({
    Key? key,
    required this.url,
    required this.title,
    this.materialId,
    this.courseName,
    this.contributorName,
    this.contributorPhoto,
    this.createdAt,
    this.courseId,
  }) : super(key: key);

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final TransformationController _transformController = TransformationController();

  bool _isBookmarked = false;
  bool _isDownloading = false;
  bool _isFullscreen = false;
  int _imageKey = 0; // Key incremented to force Image.network reload

  @override
  void initState() {
    super.initState();
    _recordView();
    _checkBookmark();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _recordView() {
    if (widget.materialId != null && widget.materialId!.isNotEmpty) {
      _firestoreService.incrementMaterialView(widget.materialId!);
    }
  }

  void _checkBookmark() async {
    if (widget.materialId == null || widget.materialId!.isEmpty) return;
    try {
      final bookmarks = await _firestoreService.getBookmarks();
      if (mounted) {
        final isBkmk = bookmarks.any((b) =>
            (b['material']?['_id'] ?? b['material']?['id']) == widget.materialId);
        setState(() => _isBookmarked = isBkmk);
      }
    } catch (_) {}
  }

  void _openSaveToFolderSheet() {
    if (widget.materialId == null || widget.materialId!.isEmpty) return;
    SaveToFolderSheet.show(
      context,
      materialId: widget.materialId!,
      courseId: widget.courseId,
      materialTitle: widget.title,
      onSaved: () {
        setState(() => _isBookmarked = true);
      },
    );
  }

  void _toggleBookmark() async {
    if (widget.materialId == null || widget.materialId!.isEmpty) return;
    final nextState = !_isBookmarked;
    setState(() => _isBookmarked = nextState);

    try {
      if (nextState) {
        await _firestoreService.addBookmark(widget.materialId!, widget.courseId ?? '');
      } else {
        await _firestoreService.removeBookmark(widget.materialId!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(nextState ? 'Resource added to bookmarks' : 'Resource removed from bookmarks'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _isBookmarked = !nextState);
    }
  }

  Future<void> _downloadImage() async {
    if (widget.materialId != null && widget.materialId!.isNotEmpty) {
      _firestoreService.incrementMaterialDownload(widget.materialId!);
    }
    setState(() => _isDownloading = true);

    try {
      final response = await http.get(Uri.parse(widget.url)).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final ext = widget.url.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
      final safeTitle = widget.title.replaceAll(RegExp(r'[^\w\s.-]'), '_');

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir != null) {
        final file = File('${dir.path}/$safeTitle$ext');
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Saved to Downloads: ${file.path}'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download failed: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _shareImage() {
    Clipboard.setData(ClipboardData(text: widget.url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Image link copied to clipboard!'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showReportDialog() {
    final reasons = [
      'Inappropriate or offensive content',
      'Wrong course or subject category',
      'Copyright or academic integrity issue',
      'Broken or unreadable image',
      'Other',
    ];
    String selectedReason = reasons.first;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.flag_outlined, color: Colors.redAccent, size: 22),
              SizedBox(width: 8),
              Text('Report Resource', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select reason for reporting:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 10),
                ...reasons.map((r) => RadioListTile<String>(
                      value: r,
                      groupValue: selectedReason,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.primaryColor,
                      title: Text(r, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedReason = val);
                      },
                    )),
                const SizedBox(height: 10),
                TextField(
                  controller: commentController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Additional details (optional)...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Thank you. Your report has been submitted for faculty review.'),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              child: const Text('Submit Report', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _handleDoubleTap() {
    if (_transformController.value.isIdentity()) {
      _transformController.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
    } else {
      _transformController.value = Matrix4.identity();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ─── 1. Top Bar ─────────────────────────────────────────────
            if (!_isFullscreen) _buildTopBar(),

            // ─── 2. Contributor & Metadata Header ───────────────────────
            if (!_isFullscreen && (widget.contributorName != null || widget.courseName != null))
              _buildMetadataHeader(),

            // ─── 3. Image Surface with InteractiveViewer ────────────────
            Expanded(
              child: _buildImageSurface(),
            ),

            // ─── 4. Bottom Controls Bar ─────────────────────────────────
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Save to Folder Button
          IconButton(
            icon: const Icon(
              Icons.bookmark_add_outlined,
              color: AppTheme.primaryColor,
              size: 22,
            ),
            onPressed: _openSaveToFolderSheet,
            tooltip: 'Save to Folder',
          ),
          // Share Button
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white70, size: 20),
            onPressed: _shareImage,
            tooltip: 'Share',
          ),
          // Popup menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
            color: const Color(0xFF1E293B),
            onSelected: (val) {
              if (val == 'save_folder') _openSaveToFolderSheet();
              if (val == 'bookmark') _toggleBookmark();
              if (val == 'download') _downloadImage();
              if (val == 'report') _showReportDialog();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'save_folder',
                child: Row(
                  children: [
                    Icon(Icons.folder_special_rounded, color: AppTheme.primaryColor, size: 18),
                    SizedBox(width: 10),
                    Text('Save to Folder', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'bookmark',
                child: Row(
                  children: [
                    Icon(
                      _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: _isBookmarked ? AppTheme.primaryColor : Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(_isBookmarked ? 'Remove Bookmark' : 'Quick Bookmark', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, color: AppTheme.primaryColor, size: 18),
                    SizedBox(width: 10),
                    Text('Download Image', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: Colors.redAccent, size: 18),
                    SizedBox(width: 10),
                    Text('Report Material', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataHeader() {
    final name = widget.contributorName ?? 'Academic Contributor';
    final course = widget.courseName ?? 'Course Material';
    final dateStr = widget.createdAt != null
        ? DateFormat('MMM d, yyyy').format(widget.createdAt!)
        : 'Recently uploaded';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : 'ED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF131D31),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              shape: BoxShape.circle,
              image: widget.contributorPhoto != null && widget.contributorPhoto!.isNotEmpty
                  ? DecorationImage(image: NetworkImage(widget.contributorPhoto!), fit: BoxFit.cover)
                  : null,
            ),
            child: widget.contributorPhoto == null || widget.contributorPhoto!.isEmpty
                ? Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '$course • $dateStr',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: const Text(
              'IMAGE NOTE',
              style: TextStyle(
                color: Color(0xFF10B981),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSurface() {
    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: Center(
        child: InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.8,
          maxScale: 5.0,
          child: Image.network(
            widget.url,
            key: ValueKey('img_${widget.url}_$_imageKey'),
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              final expected = loadingProgress.expectedTotalBytes;
              final loaded = loadingProgress.cumulativeBytesLoaded;
              final progress = expected != null ? loaded / expected : null;
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Loading Image...',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image_rounded, size: 56, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      const Text(
                        'Could not load image',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Unable to display image resource. Tap Retry to try again.',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _imageKey++;
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.restart_alt_rounded, color: Colors.white70, size: 22),
                tooltip: 'Reset Zoom',
                onPressed: () {
                  _transformController.value = Matrix4.identity();
                },
              ),
              IconButton(
                icon: Icon(
                  _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  color: Colors.white70,
                  size: 24,
                ),
                tooltip: 'Toggle Fullscreen',
                onPressed: () {
                  setState(() => _isFullscreen = !_isFullscreen);
                },
              ),
            ],
          ),
          GestureDetector(
            onTap: _isDownloading ? null : _downloadImage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _isDownloading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'Save Image',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
