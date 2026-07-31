import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/course_model.dart';

/// Manage Courses Screen — for Faculty Admins.
/// Shows all courses (active + inactive) in their department.
/// Supports Add, Edit, Delete, and Activate/Deactivate.
class ManageCoursesScreen extends StatefulWidget {
  const ManageCoursesScreen({Key? key}) : super(key: key);

  @override
  State<ManageCoursesScreen> createState() => _ManageCoursesScreenState();
}

class _ManageCoursesScreenState extends State<ManageCoursesScreen> {
  final _service = FirestoreService();
  List<CourseModel> _courses = [];
  bool _isLoading = true;
  String? _deptId;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      _deptId = user?.departmentId;
      if (_deptId == null || _deptId!.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final courses = await _service.getCoursesAdmin(_deptId!);
      if (mounted) setState(() { _courses = courses; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showCourseDialog({CourseModel? existing}) async {
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final semCtrl  = TextEditingController(text: existing?.semester ?? '');
    final creditCtrl = TextEditingController(text: existing?.credit ?? '3');
    String status = existing?.status ?? 'active';
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          final theme = Theme.of(ctx);
          final isDark = theme.brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              existing == null ? 'Add Course' : 'Edit Course',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dialogField(
                      controller: codeCtrl,
                      label: 'Course Code',
                      hint: 'e.g. CSE101',
                      isDark: isDark,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _dialogField(
                      controller: nameCtrl,
                      label: 'Course Name',
                      hint: 'e.g. Data Structures',
                      isDark: isDark,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _dialogField(
                      controller: semCtrl,
                      label: 'Semester',
                      hint: 'e.g. 3rd Semester',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _dialogField(
                      controller: creditCtrl,
                      label: 'Credit Hours',
                      hint: 'e.g. 3',
                      keyboardType: TextInputType.number,
                      isDark: isDark,
                    ),
                    if (existing != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Status', style: theme.textTheme.bodyMedium),
                          Switch(
                            value: status == 'active',
                            activeColor: AppTheme.primaryColor,
                            onChanged: (v) => setDialogState(() => status = v ? 'active' : 'inactive'),
                          ),
                        ],
                      ),
                      Text(
                        status == 'active' ? 'Active' : 'Inactive',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: status == 'active' ? const Color(0xFF10B981) : theme.disabledColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => saving = true);
                        try {
                          if (existing == null) {
                            final created = await _service.createCourse(
                              name: nameCtrl.text.trim(),
                              code: codeCtrl.text.trim(),
                              semester: semCtrl.text.trim(),
                              credit: creditCtrl.text.trim(),
                            );
                            setState(() => _courses.insert(0, created));
                          } else {
                            final updated = await _service.updateCourse(
                              existing.id,
                              name: nameCtrl.text.trim(),
                              code: codeCtrl.text.trim(),
                              semester: semCtrl.text.trim(),
                              credit: creditCtrl.text.trim(),
                              status: status,
                            );
                            setState(() {
                              final i = _courses.indexWhere((c) => c.id == existing.id);
                              if (i != -1) _courses[i] = updated;
                            });
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        } catch (e) {
                          setDialogState(() => saving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: Colors.redAccent,
                            ));
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(existing == null ? 'Add' : 'Save'),
              ),
            ],
          );
        });
      },
    );

    codeCtrl.dispose();
    nameCtrl.dispose();
    semCtrl.dispose();
    creditCtrl.dispose();
  }

  Future<void> _deleteCourse(CourseModel course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Course'),
        content: Text('Delete "${course.code}: ${course.name}"?\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteCourse(course.id);
      setState(() => _courses.removeWhere((c) => c.id == course.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Course deleted.'),
          backgroundColor: Color(0xFF10B981),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  Future<void> _toggleStatus(CourseModel course) async {
    try {
      final updated = await _service.toggleCourseStatus(course.id);
      setState(() {
        final i = _courses.indexWhere((c) => c.id == course.id);
        if (i != -1) _courses[i] = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final active = _courses.where((c) => c.isActive).length;
    final inactive = _courses.where((c) => !c.isActive).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: AppTheme.primaryColor, size: 26),
            const SizedBox(width: 10),
            Text(
              'Manage Courses',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadCourses,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCourseDialog(),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Course', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _loadCourses,
              child: _deptId == null || _deptId!.isEmpty
                  ? _emptyState(theme, 'No department assigned to your account.\nContact a Super Admin.')
                  : _courses.isEmpty
                      ? _emptyState(theme, 'No courses yet.\nTap + Add Course to get started.')
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                          children: [
                            // Summary chips
                            Row(
                              children: [
                                _chip('$active Active', const Color(0xFF10B981), isDark),
                                const SizedBox(width: 8),
                                _chip('$inactive Inactive', theme.disabledColor, isDark),
                              ],
                            ),
                            const SizedBox(height: 16),

                            ..._courses.map((course) => _CourseCard(
                              course: course,
                              isDark: isDark,
                              onEdit: () => _showCourseDialog(existing: course),
                              onDelete: () => _deleteCourse(course),
                              onToggle: () => _toggleStatus(course),
                            )),
                          ],
                        ),
            ),
    );
  }

  Widget _chip(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _emptyState(ThemeData theme, String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(msg,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: isDark ? AppTheme.darkSurface : AppTheme.lightBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ─── Course Card Widget ──────────────────────────────────────────────────────

class _CourseCard extends StatelessWidget {
  final CourseModel course;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _CourseCard({
    required this.course,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = course.isActive;
    final statusColor = isActive ? const Color(0xFF10B981) : theme.disabledColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppTheme.primaryColor.withValues(alpha: 0.25)
              : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_book_rounded, color: AppTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 14),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        course.code,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (course.semester.isNotEmpty || course.credit.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (course.semester.isNotEmpty) ...[
                          Icon(Icons.calendar_month_outlined,
                              size: 13, color: theme.textTheme.bodyMedium?.color),
                          const SizedBox(width: 3),
                          Text(course.semester,
                              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
                          const SizedBox(width: 12),
                        ],
                        if (course.credit.isNotEmpty) ...[
                          Icon(Icons.stars_outlined,
                              size: 13, color: theme.textTheme.bodyMedium?.color),
                          const SizedBox(width: 3),
                          Text('${course.credit} Credits',
                              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle active/inactive
                GestureDetector(
                  onTap: onToggle,
                  child: Tooltip(
                    message: isActive ? 'Deactivate' : 'Activate',
                    child: Icon(
                      isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                      color: isActive ? AppTheme.primaryColor : theme.disabledColor,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onEdit,
                  child: const Tooltip(
                    message: 'Edit',
                    child: Icon(Icons.edit_outlined, size: 20, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onDelete,
                  child: const Tooltip(
                    message: 'Delete',
                    child: Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
