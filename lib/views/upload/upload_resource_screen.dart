import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
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
  final _linkController = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();

  /// 'notes' | 'assignment' | 'video' | 'pdf'
  String _selectedType = 'notes';

  /// For video type: 'youtube' | 'gallery' | 'file' | null
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
    _linkController.dispose();
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

  // ─── File Pickers ─────────────────────────────────────────────────────

  Future<void> _pickVideoFromGallery() async {
    try {
      // FileType.video opens the device gallery for video files
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: true,
      );
      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
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
        allowedExtensions: ['mp4', 'mkv', 'mov', 'avi', 'webm', 'mpeg', '3gp'],
        withData: true,
      );
      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
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
      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      _showError('Could not open file picker: ${e.toString()}');
    }
  }

  Future<void> _pickDocFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
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

  // ─── Video source chooser bottom sheet ───────────────────────────────

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
                  'Select where your video comes from',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                _buildVideoSourceTile(
                  ctx,
                  icon: Icons.photo_library_rounded,
                  color: Colors.green,
                  title: 'Gallery / Device Video',
                  subtitle: 'Pick a video from your phone gallery',
                  onTap: () {
                    Navigator.pop(ctx);
                    // Reset YouTube link when switching to file
                    _linkController.clear();
                    _pickVideoFromGallery();
                  },
                ),
                const SizedBox(height: 10),
                _buildVideoSourceTile(
                  ctx,
                  icon: Icons.folder_open_rounded,
                  color: Colors.orange,
                  title: 'File Explorer / Google Drive',
                  subtitle: 'Browse files from storage or cloud',
                  onTap: () {
                    Navigator.pop(ctx);
                    _linkController.clear();
                    _pickVideoFromExplorer();
                  },
                ),
                const SizedBox(height: 10),
                _buildVideoSourceTile(
                  ctx,
                  icon: Icons.smart_display_rounded,
                  color: Colors.redAccent,
                  title: 'YouTube Link',
                  subtitle: 'Paste a YouTube video URL',
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedFile = null;
                      _videoSource = 'youtube';
                    });
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

    // Validate based on type
    if (_selectedType == 'video') {
      if (_videoSource == null) {
        _showError('Please choose a video source (Gallery, File Explorer, or YouTube).');
        return;
      }
      if (_videoSource == 'youtube') {
        final link = _linkController.text.trim();
        if (link.isEmpty) {
          _showError('Please enter a YouTube URL.');
          return;
        }
        if (!link.contains('youtube.com') && !link.contains('youtu.be')) {
          _showError('Please enter a valid YouTube URL.');
          return;
        }
      } else {
        // gallery or file
        if (_selectedFile == null) {
          _showError('Please select a video file.');
          return;
        }
        if (_selectedFile!.bytes == null) {
          _showError('Could not read the video file. Please try selecting it again.');
          return;
        }
      }
    } else {
      // notes, assignment, pdf — require a file
      if (_selectedFile == null) {
        _showError('Please select a file to upload.');
        return;
      }
      if (_selectedFile!.bytes == null) {
        _showError('Could not read file data. Please try selecting the file again.');
        return;
      }
    }

    setState(() => _isUploading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    try {
      // Determine the effective videoSource for the model
      String? effectiveVideoSource;
      String? videoLink;
      if (_selectedType == 'video') {
        if (_videoSource == 'youtube') {
          effectiveVideoSource = 'youtube';
          videoLink = _linkController.text.trim();
        } else {
          effectiveVideoSource = 'cloudinary';
        }
      }

      final newMaterial = MaterialModel(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        fileUrl: null,
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
        fileBytes: _selectedFile?.bytes,
        fileName: _selectedFile?.name,
        videoSource: effectiveVideoSource,
      );

      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Material submitted successfully for admin approval!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        widget.onUploadSuccess?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showError('Upload failed: ${e.toString()}');
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
                  hint: 'e.g. Midterm formula sheet, Assignment 1 solutions',
                  controller: _titleController,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
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
                    if (val == null || val.isEmpty) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'VIDEO SOURCE',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.brightness == Brightness.dark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // Choose Source Button / Selected State
        GestureDetector(
          onTap: _showVideoSourcePicker,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _videoSource != null ? AppTheme.primaryColor : theme.dividerColor,
                width: 1.5,
              ),
            ),
            child: _videoSource == null
                ? Row(
                    children: [
                      Icon(Icons.video_call_rounded, color: theme.disabledColor, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose Video Source',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Gallery, File Explorer, or YouTube Link',
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
                      Icon(
                        _videoSource == 'youtube'
                            ? Icons.smart_display_rounded
                            : Icons.video_file_rounded,
                        color: AppTheme.primaryColor,
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _videoSource == 'youtube'
                                  ? 'YouTube Link'
                                  : (_selectedFile?.name ?? 'Video Selected'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            if (_selectedFile != null && _videoSource != 'youtube')
                              Text(
                                '${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.swap_horiz_rounded),
                        color: AppTheme.primaryColor,
                        tooltip: 'Change source',
                        onPressed: _showVideoSourcePicker,
                      ),
                    ],
                  ),
          ),
        ),

        // YouTube URL input — shown when source is youtube
        if (_videoSource == 'youtube') ...[
          const SizedBox(height: 16),
          CustomTextField(
            label: 'YOUTUBE URL',
            hint: 'https://youtube.com/watch?v=... or https://youtu.be/...',
            controller: _linkController,
            prefixIcon: Icons.smart_display_rounded,
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please enter a YouTube URL';
              }
              if (!val.contains('youtube.com') && !val.contains('youtu.be')) {
                return 'Please enter a valid YouTube URL';
              }
              return null;
            },
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
          'PDF FILE',
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
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedFile == null
                            ? 'Open file explorer or Google Drive'
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

  // ─── Doc/Notes Picker Section ─────────────────────────────────────────

  Widget _buildDocPickerSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FILE ATTACHMENT',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.brightness == Brightness.dark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDocFile,
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
                      ? Icons.cloud_upload_outlined
                      : Icons.insert_drive_file_outlined,
                  color: _selectedFile == null ? theme.disabledColor : AppTheme.primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedFile == null ? 'Choose Document / PDF' : _selectedFile!.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedFile == null
                            ? 'Accepts PDF, DOCX, Images up to 20MB'
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
            // Reset file and video source when switching type
            _selectedFile = null;
            _videoSource = null;
            _linkController.clear();
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
