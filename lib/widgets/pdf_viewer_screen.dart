import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edushare/core/theme.dart';

/// Full-screen in-app PDF viewer.
///
/// Downloads the PDF from [url] to a temporary file, then renders it
/// with [PDFView] (flutter_pdfview). Falls back to external browser
/// if download or rendering fails.
class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const PdfViewerScreen({
    Key? key,
    required this.url,
    required this.title,
  }) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String? _localPath;
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // Download PDF to a temp file
      final response = await http.get(Uri.parse(widget.url)).timeout(
        const Duration(seconds: 60),
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final bytes = response.bodyBytes;
      final dir = await getTemporaryDirectory();
      // Use a sanitised filename
      final safeTitle = widget.title.replaceAll(RegExp(r'[^\w\s.-]'), '_');
      final file = File('${dir.path}/$safeTitle.pdf');
      await file.writeAsBytes(bytes, flush: true);

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
          _errorMessage = 'Could not load PDF: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _openExternally() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open PDF externally')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            tooltip: 'Open externally',
            onPressed: _openExternally,
          ),
        ],
      ),
      body: _buildBody(theme, isDark),
      // Page indicator bottom bar
      bottomNavigationBar: (!_isLoading && !_hasError && _totalPages > 1)
          ? Container(
              height: 40,
              color: isDark ? AppTheme.darkCard : Colors.white,
              child: Center(
                child: Text(
                  'Page ${_currentPage + 1} of $_totalPages',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            Text('Loading PDF...', style: theme.textTheme.bodyMedium),
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
              Icon(Icons.error_outline_rounded, size: 56, color: Colors.redAccent.withOpacity(0.7)),
              const SizedBox(height: 16),
              Text(
                'Could not display PDF',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'An unexpected error occurred.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.disabledColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Retry
              ElevatedButton.icon(
                onPressed: _downloadPdf,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              // External fallback
              OutlinedButton.icon(
                onPressed: _openExternally,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open in Browser'),
              ),
            ],
          ),
        ),
      );
    }

    return PDFView(
      filePath: _localPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: false,
      pageSnap: false,
      fitPolicy: FitPolicy.BOTH,
      preventLinkNavigation: false,
      onRender: (pages) {
        if (mounted) {
          setState(() {
            _totalPages = pages ?? 0;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Render error: $error';
          });
        }
      },
      onPageError: (page, error) {
        debugPrint('[PDF] Page $page error: $error');
      },
      onPageChanged: (page, total) {
        if (mounted) {
          setState(() {
            _currentPage = page ?? 0;
            _totalPages = total ?? _totalPages;
          });
        }
      },
    );
  }
}
