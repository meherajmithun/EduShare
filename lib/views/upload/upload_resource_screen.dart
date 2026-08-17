import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/department_model.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/widgets/custom_button.dart';
import 'package:edushare/widgets/custom_textfield.dart';

class UploadResourceScreen extends StatefulWidget {
  final VoidCallback? onUploadSuccess;
  final String? initialType; // 'pdf' | 'video' | 'notes' | 'assignment'
  const UploadResourceScreen({Key? key, this.onUploadSuccess, this.initialType}) : super(key: key);

  @override
  State<UploadResourceScreen> createState() => _UploadResourceScreenState();
}

class _UploadResourceScreenState extends State<UploadResourceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _videoUrlController = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();

  /// 'notes' | 'assignment' | 'video' | 'pdf'
  String _selectedType = 'notes';

  /// For video: 'url' (YouTube / Web link) | 'file' (direct video upload)
  String _videoUploadMode = 'url';

  /// For video file source: 'gallery' | 'file' | null
  String? _videoSource;

  CourseModel? _selectedCourse;
  List<CourseModel> _courses = [];
  bool _isLoadingCourses = true;
  bool _isUploading = false;

  PlatformFile? _selectedFile;

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _selectedType = widget.initialType!;
    }
    _loadCourses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  void _loadCourses() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    try {
      String deptId = user?.departmentId ?? '';

      if (deptId.isEmpty) {
        final departments = await _firestoreService.getDepartments();
        final userDept = user?.department ?? '';

        DepartmentModel? matchedDept;
        for (final dept in departments) {
          if (dept.code == userDept ||
              dept.name == userDept ||
              userDept.contains(dept.code)) {
            matchedDept = dept;
            break;
          }
        }
        deptId = matchedDept?.id ?? (departments.isNotEmpty ? departments.first.id : '');
      }

      final courses = await _firestoreService.getCourses(deptId);
      setState(() {
        _courses = courses;
        if (courses.isNotEmpty) {
          _selectedCourse = courses[0];
        }
        _isLoadingCourses = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCourses = false;
      });
    }
  }

  // ─── Helper to safely read file bytes (handles mobile path + memory) ───

  Future<Uint8List?> _getFileBytes(PlatformFile pf) async {
    try {
      if (pf.bytes != null && pf.bytes!.isNotEmpty) {
        return pf.bytes;
      }
      if (pf.path != null && pf.path!.isNotEmpty) {
        final file = File(pf.path!);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }
    } catch (e) {
      debugPrint('Error reading file bytes: $e');
    }
    return null;
  }

  // ─── File Pickers ─────────────────────────────────────────────────────

  Future<void> _pickVideoFromGallery() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.size > 200 * 1024 * 1024) {
          _showError('Video file exceeds 200 MB limit. Please select a smaller video.');
          return;
        }
        setState(() {
          _selectedFile = file;
          _videoSource = 'gallery';
        });
      }
    } catch (e) {
      _showError('Could not open gallery: ${e.toString()}');
    }
  }

  Future<void> _pickVideoFromExplorer() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mkv', 'mov', 'avi', 'webm', 'mpeg', '3gp', 'flv'],
        withData: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.size > 200 * 1024 * 1024) {
          _showError('Video file exceeds 200 MB limit. Please select a smaller video.');
          return;
        }
        setState(() {
          _selectedFile = file;
          _videoSource = 'file';
        });
      }
    } catch (e) {
      _showError('Could not open file explorer: ${e.toString()}');
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.size > 50 * 1024 * 1024) {
          _showError('PDF file exceeds 50 MB limit.');
          return;
        }
        setState(() {
          _selectedFile = file;
        });
      }
    } catch (e) {
      _showError('Could not open PDF picker: ${e.toString()}');
    }
  }

  Future<void> _pickDocOrImageFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'jpg', 'jpeg', 'png', 'webp', 'txt'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.size > 50 * 1024 * 1024) {
          _showError('File exceeds 50 MB limit.');
          return;
        }
        setState(() {
          _selectedFile = file;
        });
      }
    } catch (e) {
      _showError('Could not open file picker: ${e.toString()}');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── Video source chooser bottom sheet (Gallery & File Explorer/Drive) ───

  void _showVideoSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose Video Source',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select video file from device or cloud storage',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                _buildVideoSourceTile(
                  ctx,
                  icon: Icons.photo_library_rounded,
                  color: Colors.green,
                  title: 'Device Gallery',
                  subtitle: 'Pick recorded or stored video from gallery',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickVideoFromGallery();
                  },
                ),
                const SizedBox(height: 12),
                _buildVideoSourceTile(
                  ctx,
                  icon: Icons.folder_open_rounded,
                  color: Colors.orange,
                  title: 'File Explorer / Google Drive',
                  subtitle: 'Browse files from internal storage or cloud drive',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickVideoFromExplorer();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoSourceTile(
    BuildContext ctx, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(ctx);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: theme.disabledColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.disabledColor),
          ],
        ),
      ),
    );
  }

  // ─── Upload handler ───────────────────────────────────────────────────

  void _handleUpload() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    if (_selectedCourse == null) {
      _showError('Please select a course.');
      return;
    }

    Uint8List? fileBytes;
    String? effectiveVideoSource;
    String? videoLink;

    if (_selectedType == 'video') {
      if (_videoUploadMode == 'url') {
        final url = _videoUrlController.text.trim();
        if (url.isEmpty) {
          _showError('Please enter a YouTube or video URL.');
          return;
        }
        final parsedUri = Uri.tryParse(url);
        if (parsedUri == null || !parsedUri.hasScheme || (parsedUri.scheme != 'http' && parsedUri.scheme != 'https')) {
          _showError('Please enter a valid HTTP or HTTPS video URL.');
          return;
        }
        videoLink = url;
        effectiveVideoSource = 'youtube';
      } else {
        if (_selectedFile == null) {
          _showError('Please select a video file to upload.');
          return;
        }
        fileBytes = await _getFileBytes(_selectedFile!);
        if (fileBytes == null || fileBytes.isEmpty) {
          _showError('Could not read the selected video file. Please try selecting it again.');
          return;
        }
        effectiveVideoSource = 'cloudinary';
      }
    } else {
      if (_selectedFile == null) {
        if (_selectedType == 'pdf') {
          _showError('Please select a PDF file to upload.');
        } else {
          _showError('Please select a document or image file to upload.');
        }
        return;
      }
      fileBytes = await _getFileBytes(_selectedFile!);
      if (fileBytes == null || fileBytes.isEmpty) {
        _showError('Could not read the selected file data. Please try re-selecting it.');
        return;
      }
    }

    setState(() => _isUploading = true);

    try {
      final newMaterial = MaterialModel(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        fileUrl: videoLink,
        videoLink: videoLink,
        videoSource: effectiveVideoSource,
        courseId: _selectedCourse?.id ?? '',
        departmentId: _selectedCourse?.departmentId ?? '',
        uploadedBy: currentUser?.uid ?? '',
        contributorName: currentUser?.name ?? 'Anonymous Contributor',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await _firestoreService.uploadMaterial(
        newMaterial,
        fileBytes: fileBytes,
        fileName: _selectedFile?.name,
        videoSource: effectiveVideoSource,
      );

      if (mounted) {
        setState(() => _isUploading = false);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Material submitted successfully for admin approval!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        widget.onUploadSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        final rawMsg = e.toString();
        final cleanMsg = rawMsg
            .replaceAll('Exception: ', '')
            .replaceAll('ValidationException: ', '')
            .replaceAll('ServerException: ', '')
            .replaceAll('NetworkException: ', '')
            .replaceAll('ForbiddenException: ', '')
            .replaceAll('UnauthorizedException: ', '')
            .replaceAll('NotFoundException: ', '');
        _showError(cleanMsg.isNotEmpty ? cleanMsg : 'Upload failed. Please try again.');
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pull-down indicator bar
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Share Academic Resource',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your upload will be visible once approved by an admin.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                // Resource Type Toggle Buttons
                Row(
                  children: [
                    _buildTypeOption('notes', 'Notes', Icons.description_rounded),
                    const SizedBox(width: 8),
                    _buildTypeOption('assignment', 'Assignment', Icons.assignment_rounded),
                    const SizedBox(width: 8),
                    _buildTypeOption('video', 'Video', Icons.video_library_rounded),
                    const SizedBox(width: 8),
                    _buildTypeOption('pdf', 'PDF', Icons.picture_as_pdf_rounded),
                  ],
                ),
                const SizedBox(height: 24),

                // Course Selector Dropdown
                if (_isLoadingCourses)
                  const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                else if (_courses.isEmpty)
                  Text('No courses available in your department.', style: theme.textTheme.bodyMedium)
                else ...[
                  Text(
                    'SELECT COURSE',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.brightness == Brightness.dark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<CourseModel>(
                    value: _selectedCourse,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    icon: const Icon(Icons.arrow_drop_down_rounded, size: 28),
                    items: _courses.map((course) {
                      return DropdownMenuItem(
                        value: course,
                        child: Text('${course.code}: ${course.name}', style: theme.textTheme.bodyMedium),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCourse = val;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 20),

                // Title Input
                CustomTextField(
                  label: 'RESOURCE TITLE',
                  hint: 'e.g. Lecture 5 Notes, Assignment 1 Solution, Chapter 3 Guide',
                  controller: _titleController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Description Input
                CustomTextField(
                  label: 'DESCRIPTION / TOPICS COVERED',
                  hint: 'Describe topics or contents of this material...',
                  controller: _descriptionController,
                  maxLines: 3,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ─── Dynamic input based on type ─────────────────────────
                if (_selectedType == 'video') ...[
                  _buildVideoUploadSection(theme),
                ] else if (_selectedType == 'pdf') ...[
                  _buildPdfPickerSection(theme),
                ] else ...[
                  _buildDocPickerSection(theme),
                ],

                const SizedBox(height: 32),

                CustomButton(
                  text: 'Submit for Approval',
                  isLoading: _isUploading,
                  onPressed: _handleUpload,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Video Upload Section ─────────────────────────────────────────────

  Widget _buildVideoUploadSection(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final ytId = YoutubePlayer.convertUrlToId(_videoUrlController.text.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode Selector: URL vs File Upload
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _videoUploadMode = 'url'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _videoUploadMode == 'url'
                        ? AppTheme.primaryColor.withOpacity(0.15)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _videoUploadMode == 'url' ? AppTheme.primaryColor : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 18,
                        color: _videoUploadMode == 'url' ? AppTheme.primaryColor : theme.disabledColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'YouTube / Video URL',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _videoUploadMode == 'url' ? AppTheme.primaryColor : theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _videoUploadMode = 'file'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _videoUploadMode == 'file'
                        ? AppTheme.primaryColor.withOpacity(0.15)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _videoUploadMode == 'file' ? AppTheme.primaryColor : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.upload_file_rounded,
                        size: 18,
                        color: _videoUploadMode == 'file' ? AppTheme.primaryColor : theme.disabledColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Upload Video File',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _videoUploadMode == 'file' ? AppTheme.primaryColor : theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_videoUploadMode == 'url') ...[
          CustomTextField(
            label: 'YOUTUBE OR VIDEO URL',
            hint: 'https://www.youtube.com/watch?v=... or https://youtu.be/...',
            controller: _videoUrlController,
            onChanged: (_) => setState(() {}),
            validator: (val) {
              if (_selectedType == 'video' && _videoUploadMode == 'url') {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a video URL';
                }
                final uri = Uri.tryParse(val.trim());
                if (uri == null || !uri.hasScheme || (!uri.scheme.startsWith('http'))) {
                  return 'Please enter a valid URL (starting with http:// or https://)';
                }
              }
              return null;
            },
          ),
          if (ytId != null && ytId.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Valid YouTube Video detected (ID: $ytId)',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ] else ...[
          Text(
            'VIDEO FILE',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showVideoSourcePicker,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedFile != null ? AppTheme.primaryColor : theme.dividerColor,
                  width: 1.5,
                ),
              ),
              child: _selectedFile == null
                  ? Row(
                      children: [
                        Icon(Icons.video_call_rounded, color: theme.disabledColor, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Choose Video File',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'From Gallery or File Explorer / Google Drive',
                                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: theme.disabledColor),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(
                          Icons.video_file_rounded,
                          color: AppTheme.primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedFile?.name ?? 'Video Selected',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB • ${_videoSource == 'gallery' ? 'Gallery' : 'Drive / Storage'}',
                                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.swap_horiz_rounded),
                          color: AppTheme.primaryColor,
                          tooltip: 'Change video',
                          onPressed: _showVideoSourcePicker,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ],
    );
  }

  // ─── PDF Picker Section ───────────────────────────────────────────────

  Widget _buildPdfPickerSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PDF DOCUMENT',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.brightness == Brightness.dark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickPdf,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedFile == null ? theme.dividerColor : AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedFile == null
                      ? Icons.picture_as_pdf_outlined
                      : Icons.picture_as_pdf_rounded,
                  color: _selectedFile == null ? theme.disabledColor : Colors.redAccent,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedFile == null ? 'Choose PDF File' : _selectedFile!.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedFile == null
                            ? 'Browse PDF from device or Google Drive'
                            : '${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (_selectedFile != null)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Colors.redAccent),
                    onPressed: () => setState(() => _selectedFile = null),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Doc/Image/Notes Picker Section ───────────────────────────────────

  Widget _buildDocPickerSection(ThemeData theme) {
    IconData fileIcon = Icons.cloud_upload_outlined;
    Color iconColor = theme.disabledColor;

    if (_selectedFile != null) {
      final ext = _selectedFile!.name.toLowerCase().split('.').last;
      if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
        fileIcon = Icons.image_rounded;
        iconColor = Colors.tealAccent;
      } else if (ext == 'pdf') {
        fileIcon = Icons.picture_as_pdf_rounded;
        iconColor = Colors.redAccent;
      } else {
        fileIcon = Icons.insert_drive_file_rounded;
        iconColor = AppTheme.primaryColor;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedType == 'assignment' ? 'ASSIGNMENT FILE (PDF / IMAGE / DOC)' : 'NOTES FILE (PDF / IMAGE / DOC)',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.brightness == Brightness.dark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDocOrImageFile,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedFile == null ? theme.dividerColor : AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  fileIcon,
                  color: iconColor,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedFile == null ? 'Choose Image, PDF or Document' : _selectedFile!.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedFile == null
                            ? 'Accepts JPG, PNG, WEBP, PDF, DOCX'
                            : '${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (_selectedFile != null)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Colors.redAccent),
                    onPressed: () => setState(() => _selectedFile = null),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Type Option Button ───────────────────────────────────────────────

  Widget _buildTypeOption(String type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _selectedFile = null;
            _videoSource = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withOpacity(0.12) : theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : theme.dividerColor,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.primaryColor : theme.disabledColor,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.primaryColor : theme.textTheme.bodyLarge?.color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
