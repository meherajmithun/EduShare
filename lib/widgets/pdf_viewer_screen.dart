import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/app_config.dart';
import 'package:edushare/core/services/session_service.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/widgets/save_to_folder_sheet.dart';
import 'package:intl/intl.dart';

/// In-app PDF viewer matching the Video Player dark sleek visual style.
class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  final String? materialId;
  final String? courseName;
  final String? contributorName;
  final String? contributorPhoto;
  final DateTime? createdAt;
  final String? courseId;

  const PdfViewerScreen({
    super.key,
    required this.url,
    required this.title,
    this.materialId,
    this.courseName,
    this.contributorName,
    this.contributorPhoto,
    this.createdAt,
    this.courseId,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  PDFViewController? _pdfViewController;

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String? _localPath;

  int _totalPages = 0;
  int _currentPage = 0;
  int _initialSavedPage = 0;
  bool _isBookmarked = false;
  bool _isDownloading = false;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _recordView();
    _checkBookmark();
    _loadSavedProgress();
    _downloadPdf();
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

  void _loadSavedProgress() async {
    if (widget.materialId == null || widget.materialId!.isEmpty) return;
    try {
      final prog = await _firestoreService.getPdfProgress(widget.materialId!);
      final page = (prog['currentPage'] as num?)?.toInt() ?? 1;
      if (page > 1) {
        _initialSavedPage = page - 1; // 0-indexed for PDFView
      }
    } catch (_) {}
  }

  void _saveProgress(int pageIndex, int total) {
    if (widget.materialId == null || widget.materialId!.isEmpty || total <= 0) return;
    final curPage = pageIndex + 1;
    final pct = ((curPage / total) * 100).clamp(0.0, 100.0);
    _firestoreService.savePdfProgress(
      widget.materialId!,
      currentPage: curPage,
      totalPages: total,
      progressPercentage: pct,
      courseId: widget.courseId,
    );
  }

  Future<void> _downloadPdf() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final token = await SessionService.instance.getToken();
      final authHeaders = token != null && token.isNotEmpty
          ? {'Authorization': 'Bearer $token'}
          : <String, String>{};

      // Candidate URLs to try in order:
      // 1. fl_attachment delivery (Cloudinary's standard way to deliver PDF binaries from image/upload)
      // 2. Backend streaming proxy endpoint
      // 3. Direct widget.url & raw/image variations
      final candidateUrls = <String>[];

      if (widget.url.isNotEmpty) {
        if (widget.url.contains('/image/upload/') && widget.url.toLowerCase().contains('.pdf')) {
          candidateUrls.add(widget.url.replaceFirst('/image/upload/', '/image/upload/fl_attachment/'));
          candidateUrls.add(widget.url.replaceFirst('/image/upload/', '/image/upload/fl_attachment,fl_sanitize/'));
          candidateUrls.add(widget.url.replaceAll('/image/upload/', '/raw/upload/'));
        } else if (widget.url.contains('/raw/upload/') && widget.url.toLowerCase().contains('.pdf')) {
          candidateUrls.add(widget.url);
          candidateUrls.add(widget.url.replaceAll('/raw/upload/', '/image/upload/fl_attachment/'));
        }

        if (widget.url.contains('cloudinary.com') && !widget.url.contains('/fl_attachment/')) {
          candidateUrls.add(widget.url.replaceFirst('/upload/', '/upload/fl_attachment/'));
        }
        candidateUrls.add(widget.url);
      }

      if (widget.materialId != null && widget.materialId!.isNotEmpty) {
        candidateUrls.add('${AppConfig.baseUrl}/api/materials/${widget.materialId}/file');
      }

      final uniqueUrls = candidateUrls.toSet().toList();
      Uint8List? fileBytes;
      String? lastError;

      for (final url in uniqueUrls) {
        try {
          final isBackendUrl = url.contains(AppConfig.baseUrl);
          final response = await http
              .get(
                Uri.parse(url),
                headers: isBackendUrl ? authHeaders : null,
              )
              .timeout(const Duration(seconds: 40));

          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            fileBytes = response.bodyBytes;
            break;
          } else {
            lastError = 'HTTP ${response.statusCode}';
          }
        } catch (err) {
          lastError = err.toString();
        }
      }

      if (fileBytes == null || fileBytes.isEmpty) {
        throw Exception(lastError ?? 'Could not retrieve PDF data.');
      }

      final dir = await getTemporaryDirectory();
      final safeTitle = widget.title.replaceAll(RegExp(r'[^\w\s.-]'), '_');
      final file = File('${dir.path}/$safeTitle.pdf');
      await file.writeAsBytes(fileBytes, flush: true);

      if (mounted) {
        setState(() {
          _localPath = file.path;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Could not load PDF: ${e.toString().replaceAll("Exception: ", "")}';
        });
      }
    }
  }

  Future<void> _downloadToDevice() async {
    if (widget.materialId != null && widget.materialId!.isNotEmpty) {
      _firestoreService.incrementMaterialDownload(widget.materialId!);
    }
    setState(() => _isDownloading = true);

    try {
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

      if (dir != null && _localPath != null) {
        final targetFile = File('${dir.path}/$safeTitle.pdf');
        final sourceFile = File(_localPath!);
        await sourceFile.copy(targetFile.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Saved to Downloads: ${targetFile.path}'),
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

  void _sharePdf() {
    Clipboard.setData(ClipboardData(text: widget.url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('PDF link copied to clipboard!'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _openExternally() async {
    if (widget.materialId != null && widget.materialId!.isNotEmpty) {
      _firestoreService.incrementMaterialDownload(widget.materialId!);
    }
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open PDF in browser')),
        );
      }
    }
  }

  void _showReportDialog() {
    final reasons = [
      'Inappropriate or offensive content',
      'Wrong course or subject category',
      'Copyright or academic integrity issue',
      'Broken or corrupted PDF file',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // ─── 1. Top Bar Matching Video Player ──────────────────────
            if (!_isFullscreen) _buildTopBar(isDark),

            // ─── 2. Contributor & Metadata Header ───────────────────────
            if (!_isFullscreen && (widget.contributorName != null || widget.courseName != null))
              _buildMetadataHeader(isDark),

            // ─── 3. PDF View Surface ────────────────────────────────────
            Expanded(
              child: _buildPdfSurface(),
            ),

            // ─── 4. Bottom Controls & Reading Progress Bar ──────────────
            if (!_isLoading && !_hasError) _buildBottomControls(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
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
            onPressed: _sharePdf,
            tooltip: 'Share',
          ),
          // More Options Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
            color: const Color(0xFF1E293B),
            onSelected: (val) {
              if (val == 'save_folder') _openSaveToFolderSheet();
              if (val == 'bookmark') _toggleBookmark();
              if (val == 'download') _downloadToDevice();
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
                    Text('Download to Device', style: TextStyle(color: Colors.white, fontSize: 13)),
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

  Widget _buildMetadataHeader(bool isDark) {
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
          // Page Badge
          if (_totalPages > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPdfSurface() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text(
              'Loading PDF Document...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_hasError || _localPath == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text(
                'Could not load PDF',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'An error occurred while opening the document.',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _downloadPdf,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _openExternally,
                icon: const Icon(Icons.open_in_browser_rounded, size: 16, color: Colors.white70),
                label: const Text('Open in Browser', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        PDFView(
          filePath: _localPath!,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          pageSnap: true,
          defaultPage: _initialSavedPage,
          fitPolicy: FitPolicy.BOTH,
          preventLinkNavigation: false,
          onViewCreated: (controller) {
            _pdfViewController = controller;
          },
          onRender: (pages) {
            if (mounted) {
              setState(() {
                _totalPages = pages ?? 0;
              });
              if (_initialSavedPage > 0) {
                _pdfViewController?.setPage(_initialSavedPage);
              }
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = error.toString();
              });
            }
          },
          onPageChanged: (page, total) {
            if (mounted && page != null) {
              setState(() {
                _currentPage = page;
                _totalPages = total ?? _totalPages;
              });
              _saveProgress(page, _totalPages);
            }
          },
        ),
        // Floating Fullscreen toggle button
        Positioned(
          right: 14,
          top: 14,
          child: GestureDetector(
            onTap: () => setState(() => _isFullscreen = !_isFullscreen),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Row(
        children: [
          // Previous Page Button
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
            onPressed: _currentPage > 0
                ? () {
                    final prev = _currentPage - 1;
                    _pdfViewController?.setPage(prev);
                  }
                : null,
          ),
          // Page Slider
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.primaryColor,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 3,
              ),
              child: Slider(
                value: _totalPages > 1
                    ? (_currentPage / (_totalPages - 1)).clamp(0.0, 1.0)
                    : 0.0,
                onChanged: _totalPages > 1
                    ? (val) {
                        final target = (val * (_totalPages - 1)).round();
                        _pdfViewController?.setPage(target);
                      }
                    : null,
              ),
            ),
          ),
          // Next Page Button
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
            onPressed: (_currentPage < _totalPages - 1)
                ? () {
                    final next = _currentPage + 1;
                    _pdfViewController?.setPage(next);
                  }
                : null,
          ),
          const SizedBox(width: 8),
          // Quick Download Action
          GestureDetector(
            onTap: _isDownloading ? null : _downloadToDevice,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    'Save',
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
