import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/core/role_helper.dart';
import 'package:edushare/models/department_model.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/widgets/glass_card.dart';
import 'package:edushare/widgets/notification_bell.dart';
import 'package:edushare/widgets/app_bar_profile_avatar.dart';
import 'package:edushare/views/course/course_details_screen.dart';

/// Dedicated Search tab — search courses by name/code, filter by department.
class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        _departments = (user != null && (user.isStudent || user.isContributor) && userDept != null)
            ? [userDept]
            : depts;
        _allCourses = courses;
        _filteredCourses = courses;
        _selectedDept = userDept;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterCourses(String query) {
    setState(() {
      _searchQuery = query;
      _filteredCourses = _allCourses.where((course) {
        final matchesQuery =
            course.name.toLowerCase().contains(query.toLowerCase()) ||
                course.code.toLowerCase().contains(query.toLowerCase());
        final matchesDept =
            _selectedDept == null || course.departmentId == _selectedDept!.id;
        return matchesQuery && matchesDept;
      }).toList();
    });
  }

  void _selectDepartment(DepartmentModel? dept) {
    // Merge into a single setState to avoid two rebuild cycles.
    setState(() {
      _selectedDept = dept;
      _filteredCourses = _allCourses.where((course) {
        final matchesQuery =
            course.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                course.code.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesDept =
            dept == null || course.departmentId == dept.id;
        return matchesQuery && matchesDept;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 180,
        leading: const AppBarProfileAvatar(),
        actions: const [NotificationBell()],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search bar
                  TextField(
                    controller: _searchController,
                    onChanged: _filterCourses,
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: 'Search by course name or code...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                _filterCourses('');
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Department filter chips
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildDeptChip(null, 'All', theme),
                        ..._departments
                            .map((d) => _buildDeptChip(d, d.code, theme)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Results header
                  Text(
                    _searchQuery.isEmpty
                        ? (_selectedDept == null
                            ? 'All Courses (${_filteredCourses.length})'
                            : '${_selectedDept!.name} (${_filteredCourses.length})')
                        : 'Results for "$_searchQuery" (${_filteredCourses.length})',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Course list
                  Expanded(
                    child: _filteredCourses.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded,
                                    size: 52,
                                    color: theme.disabledColor),
                                const SizedBox(height: 12),
                                Text('No courses found',
                                    style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredCourses.length,
                            itemBuilder: (context, index) {
                              final course = _filteredCourses[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(16),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CourseDetailsScreen(course: course),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.menu_book_rounded,
                                          color: AppTheme.primaryColor,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              course.code,
                                              style: theme
                                                  .textTheme.labelLarge
                                                  ?.copyWith(
                                                color: AppTheme.primaryColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              course.name,
                                              style: theme
                                                  .textTheme.titleMedium
                                                  ?.copyWith(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded,
                                          color: theme.disabledColor),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDeptChip(
      DepartmentModel? dept, String label, ThemeData theme) {
    final isSelected = dept == null
        ? _selectedDept == null
        : _selectedDept?.id == dept.id;

    return GestureDetector(
      onTap: () => _selectDepartment(dept),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : theme.dividerColor,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
