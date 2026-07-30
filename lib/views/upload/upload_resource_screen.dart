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
  const UploadResourceScreen({Key? key, this.onUploadSuccess}) : super(key: key);

  @override
  State<UploadResourceScreen> createState() => _UploadResourceScreenState();
}

class _UploadResourceScreenState extends State<UploadResourceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();

  String _selectedType = 'notes'; // 'notes' | 'assignment' | 'video'
  CourseModel? _selectedCourse;
  List<CourseModel> _courses = [];
  bool _isLoadingCourses = true;
  bool _isUploading = false;
  
  PlatformFile? _selectedFile;

  @override
  void initState() {
    super.initState();
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
      // Fetch all departments, then match on the user's department name
      // to get the real MongoDB ObjectId for the courses query.
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
      // Fall back to first department if no match
      final deptId = matchedDept?.id ?? (departments.isNotEmpty ? departments.first.id : '');

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

  void _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        withData: true, // Ensures bytes are always populated (cross-platform safe)
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file picker: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _handleUpload() async {
    if (!_formKey.currentState!.validate()) return;

    // For file-based types, validate that a file was selected AND bytes are available
    if (_selectedType != 'video') {
      if (_selectedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a PDF or document file to upload'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
      if (_selectedFile!.bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not read file data. Please try selecting the file again.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    }

    setState(() {
      _isUploading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    try {
      final newMaterial = MaterialModel(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        fileUrl: null,
        videoLink: _selectedType == 'video' ? _linkController.text.trim() : null,
        courseId: _selectedCourse?.id ?? '',
        departmentId: _selectedCourse?.departmentId ?? '',
        uploadedBy: currentUser?.uid ?? '',
        contributorName: currentUser?.name ?? 'Anonymous Contributor',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      // Upload using file bytes (cross-platform: works even when path is null)
      await _firestoreService.uploadMaterial(
        newMaterial,
        fileBytes: _selectedType != 'video' ? _selectedFile!.bytes : null,
        fileName: _selectedType != 'video' ? _selectedFile!.name : null,
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Material submitted successfully for admin approval!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        // Notify parent to refresh the uploads list, then close
        widget.onUploadSuccess?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

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
                    _buildTypeOption('video', 'Video Lecture', Icons.video_library_rounded),
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

                // Dynamic Input based on Type: Video Link vs. File Picker
                if (_selectedType == 'video') ...[
                  CustomTextField(
                    label: 'VIDEO LINK (YOUTUBE / GOOGLE DRIVE)',
                    hint: 'https://youtube.com/watch?v=...',
                    controller: _linkController,
                    prefixIcon: Icons.link_rounded,
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please enter a video link';
                      }
                      if (!val.startsWith('http')) {
                        return 'Please enter a valid URL';
                      }
                      return null;
                    },
                  ),
                ] else ...[
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
                    onTap: _pickFile,
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
                              onPressed: () {
                                setState(() {
                                  _selectedFile = null;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
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

  Widget _buildTypeOption(String type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
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
                  fontSize: 11,
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
