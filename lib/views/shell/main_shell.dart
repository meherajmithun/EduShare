import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/role_helper.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/views/home/home_screen.dart';
import 'package:edushare/views/home/search_screen.dart';
import 'package:edushare/views/upload/upload_resource_screen.dart';
import 'package:edushare/views/upload/my_uploads_screen.dart';
import 'package:edushare/views/profile/profile_screen.dart';
import 'package:edushare/views/admin/admin_dashboard_screen.dart';
import 'package:edushare/views/admin/approvals_screen.dart';
import 'package:edushare/views/admin/all_materials_screen.dart';
import 'package:edushare/views/admin/users_screen.dart';
import 'package:edushare/views/admin/faculty_admins_screen.dart';
import 'package:edushare/views/admin/manage_courses_screen.dart';

/// Role-aware navigation shell.
/// Dynamically builds bottom navigation tabs based on the logged-in user's role:
///   Student       → Home · Search · Profile
///   Contributor   → Home · Search · Upload · My Uploads · Profile
///   Admin         → Dashboard · Approvals · Materials · Users · Profile
///   Faculty Admin → Dashboard · Approvals · Materials · Users · Profile
///   Super Admin   → Dashboard · Admins · Users · Profile
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // Cache tabs so they are not rebuilt on every AuthService notification.
  List<_TabItem>? _tabs;
  String? _cachedRole;

  List<_TabItem> _getTabsForRole(String role) {
    if (_cachedRole == role && _tabs != null) return _tabs!;
    _cachedRole = role;
    _tabs = _buildTabs(role);
    return _tabs!;
  }

  @override
  Widget build(BuildContext context) {
    // Select only the user — avoids rebuild on isLoading changes.
    final user = context.select<AuthService, UserModel?>(
      (s) => s.currentUser,
    );

    if (user == null) return const SizedBox.shrink();

    final tabs = _getTabsForRole(user.role);

    // Clamp index in case role changes
    if (_currentIndex >= tabs.length) _currentIndex = 0;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs.map((t) => t.screen).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          // Upload tab for contributor opens as modal bottom sheet
          if (user.canUpload &&
              user.isContributor &&
              _uploadTabIndex(user.role) == index) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const UploadResourceScreen(),
            );
            return;
          }
          setState(() => _currentIndex = index);
        },
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkSurface
            : AppTheme.lightSurface,
        indicatorColor: AppTheme.primaryColor.withOpacity(0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon),
                  selectedIcon:
                      Icon(t.selectedIcon, color: AppTheme.primaryColor),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }

  /// Returns the index of the Upload tab (modal). -1 if not applicable.
  int _uploadTabIndex(String role) {
    if (role == 'contributor') return 2;
    return -1;
  }

  List<_TabItem> _buildTabs(String role) {
    switch (role) {
      // ── Super Admin ───────────────────────────────────────────────────
      case 'super_admin':
        return const [
          _TabItem(
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            screen: AdminDashboardScreen(),
          ),
          _TabItem(
            label: 'Admins',
            icon: Icons.admin_panel_settings_outlined,
            selectedIcon: Icons.admin_panel_settings_rounded,
            screen: FacultyAdminsScreen(),
          ),
          _TabItem(
            label: 'Users',
            icon: Icons.people_outline_rounded,
            selectedIcon: Icons.people_rounded,
            screen: UsersScreen(),
          ),
          _TabItem(
            label: 'Profile',
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            screen: ProfileScreen(),
          ),
        ];

      // ── Faculty Admin ─────────────────────────────────────────────────
      case 'faculty_admin':
        return const [
          _TabItem(
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            screen: AdminDashboardScreen(),
          ),
          _TabItem(
            label: 'Courses',
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book_rounded,
            screen: ManageCoursesScreen(),
          ),
          _TabItem(
            label: 'Approvals',
            icon: Icons.pending_actions_outlined,
            selectedIcon: Icons.pending_actions_rounded,
            screen: ApprovalsScreen(),
          ),
          _TabItem(
            label: 'Materials',
            icon: Icons.folder_outlined,
            selectedIcon: Icons.folder_rounded,
            screen: AllMaterialsScreen(),
          ),
          _TabItem(
            label: 'Users',
            icon: Icons.people_outline_rounded,
            selectedIcon: Icons.people_rounded,
            screen: UsersScreen(),
          ),
          _TabItem(
            label: 'Profile',
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            screen: ProfileScreen(),
          ),
        ];

      // ── Legacy Admin ──────────────────────────────────────────────────
      case 'admin':
        return const [
          _TabItem(
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            screen: AdminDashboardScreen(),
          ),
          _TabItem(
            label: 'Approvals',
            icon: Icons.pending_actions_outlined,
            selectedIcon: Icons.pending_actions_rounded,
            screen: ApprovalsScreen(),
          ),
          _TabItem(
            label: 'Materials',
            icon: Icons.folder_outlined,
            selectedIcon: Icons.folder_rounded,
            screen: AllMaterialsScreen(),
          ),
          _TabItem(
            label: 'Users',
            icon: Icons.people_outline_rounded,
            selectedIcon: Icons.people_rounded,
            screen: UsersScreen(),
          ),
          _TabItem(
            label: 'Profile',
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            screen: ProfileScreen(),
          ),
        ];

      // ── Contributor ───────────────────────────────────────────────────
      case 'contributor':
        return const [
          _TabItem(
            label: 'Home',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            screen: HomeScreen(),
          ),
          _TabItem(
            label: 'Search',
            icon: Icons.search_outlined,
            selectedIcon: Icons.search_rounded,
            screen: SearchScreen(),
          ),
          _TabItem(
            label: 'Upload',
            icon: Icons.add_circle_outline_rounded,
            selectedIcon: Icons.add_circle_rounded,
            screen: SizedBox.shrink(), // Modal — not a screen
          ),
          _TabItem(
            label: 'My Uploads',
            icon: Icons.cloud_upload_outlined,
            selectedIcon: Icons.cloud_upload_rounded,
            screen: MyUploadsScreen(),
          ),
          _TabItem(
            label: 'Profile',
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            screen: ProfileScreen(),
          ),
        ];

      // ── Student (default) ─────────────────────────────────────────────
      default:
        return const [
          _TabItem(
            label: 'Home',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            screen: HomeScreen(),
          ),
          _TabItem(
            label: 'Search',
            icon: Icons.search_outlined,
            selectedIcon: Icons.search_rounded,
            screen: SearchScreen(),
          ),
          _TabItem(
            label: 'Profile',
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            screen: ProfileScreen(),
          ),
        ];
    }
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.screen,
  });
}
