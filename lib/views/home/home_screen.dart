import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/department_model.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/core/role_helper.dart';
import 'package:edushare/widgets/glass_card.dart';
import 'package:edushare/widgets/notification_bell.dart';
import 'package:edushare/views/course/course_details_screen.dart';
import 'package:edushare/views/upload/upload_resource_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<DepartmentModel> _departments = [];
  List<CourseModel> _allCourses = [];
  List<CourseModel> _filteredCourses = [];
  bool _isLoading = true;
  String _searchQuery = '';
  DepartmentModel? _selectedDept;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      final depts = await _firestoreService.getDepartments();

      DepartmentModel? userDept;
      if (user != null && (user.isStudent || user.isContributor)) {
        for (final dept in depts) {
          if (dept.id == user.departmentId ||
              dept.code == user.department ||
              dept.name == user.department ||
              user.department.contains(dept.code)) {
            userDept = dept;
            break;
          }
        }
      }

      List<CourseModel> courses = [];
      if (userDept != null) {
        courses = await _firestoreService.getCourses(userDept.id);
      } else {
        for (var dept in depts) {
          final deptCourses = await _firestoreService.getCourses(dept.id);
          courses.addAll(deptCourses);
        }
      }

      setState(() {
        _departments = depts;
        _allCourses = courses;
        _filteredCourses = courses;
        _selectedDept = userDept;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterCourses(String query) {
    setState(() {
      _searchQuery = query;
      _filteredCourses = _allCourses.where((course) {
        final matchesQuery = course.name.toLowerCase().contains(query.toLowerCase()) ||
            course.code.toLowerCase().contains(query.toLowerCase());
        final matchesDept = _selectedDept == null || course.departmentId == _selectedDept!.id;
        return matchesQuery && matchesDept;
      }).toList();
    });
  }

  void _selectDepartment(DepartmentModel? dept) {
    setState(() {
      _selectedDept = dept;
      _filterCourses(_searchQuery);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Select only currentUser — not isLoading — to minimise rebuilds.
    final currentUser =
        context.select<AuthService, UserModel?>((s) => s.currentUser);

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.school_rounded, color: AppTheme.primaryColor, size: 28),
            SizedBox(width: 10),
            Text(
              'EduShare',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: const [NotificationBell()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Greeting Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${currentUser?.name ?? 'Student'}!',
                      style: theme.textTheme.displayLarge?.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentUser?.department ?? 'Explore courses & notes',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getRoleColor(currentUser?.role).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getRoleColor(currentUser?.role),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    currentUser?.role.toUpperCase() ?? 'STUDENT',
                    style: TextStyle(
                      color: _getRoleColor(currentUser?.role),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Info / Upload Banner for Contributors / Admins
            if (currentUser?.role == 'contributor' || currentUser?.role == 'admin') ...[
              GlassCard(
                color: AppTheme.primaryColor.withOpacity(0.1),
                border: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share your materials',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Upload notes, assignments, or video links to help your peers.',
                            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const UploadResourceScreen(),
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 18),
                          SizedBox(width: 4),
                          Text('Upload', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Search Bar
            TextField(
              onChanged: _filterCourses,
              decoration: InputDecoration(
                hintText: 'Search by course name or code...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _filterCourses('');
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 24),

            // Departments Section Title
            Text(
              'Departments',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),

            // Department Horizontal Tabs
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  GestureDetector(
                    onTap: () => _selectDepartment(null),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: _selectedDept == null
                            ? AppTheme.primaryColor
                            : theme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selectedDept == null
                              ? AppTheme.primaryColor
                              : theme.dividerColor,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'All Courses',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: _selectedDept == null ? Colors.white : theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ..._departments.map((dept) {
                    final isSelected = _selectedDept?.id == dept.id;
                    return GestureDetector(
                      onTap: () => _selectDepartment(dept),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor : theme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryColor : theme.dividerColor,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            dept.code,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Course Grid
            Text(
              _selectedDept == null
                  ? 'All Available Courses'
                  : '${_selectedDept!.name} Courses',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),

            if (_filteredCourses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.menu_book_rounded, size: 48, color: theme.disabledColor),
                      const SizedBox(height: 12),
                      Text('No courses found', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: _filteredCourses.length,
                itemBuilder: (context, index) {
                  final course = _filteredCourses[index];
                  return GlassCard(
                    padding: const EdgeInsets.all(16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CourseDetailsScreen(course: course),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.code,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              course.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  static Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFEF4444);
      case 'contributor':
        return const Color(0xFF10B981);
      default:
        return AppTheme.primaryColor;
    }
  }
}
