import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/core/role_helper.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/widgets/glass_card.dart';

/// User management screen for admin-class roles.
/// Super Admin: sees all roles across system.
/// Faculty Admin: sees only their department's users.
class UsersScreen extends StatefulWidget {
  const UsersScreen({Key? key}) : super(key: key);

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _service = FirestoreService();
  List<UserModel> _users = [];
  List<UserModel> _filtered = [];
  bool _isLoading = true;
  String _filterRole = 'all';

  final _roles = [
    {'value': 'all', 'label': 'All'},
    {'value': 'student', 'label': 'Students'},
    {'value': 'contributor', 'label': 'Contributors'},
    {'value': 'admin', 'label': 'Admins'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final currentUser =
          Provider.of<AuthService>(context, listen: false).currentUser;
      List<UserModel> users;

      if (currentUser != null && currentUser.isSuperAdmin) {
        users = await _service.getAllUsers();
      } else {
        users = await _service.getUsers();
      }

      if (mounted) {
        setState(() {
          _users = users;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final currentUser =
        Provider.of<AuthService>(context, listen: false).currentUser;
    // Always hide super_admin user accounts from non-super_admin users
    final visibleUsers = _users.where((u) {
      if (u.role == 'super_admin' && !(currentUser?.isSuperAdmin ?? false)) {
        return false;
      }
      return true;
    }).toList();

    if (_filterRole == 'all') {
      _filtered = visibleUsers;
    } else if (_filterRole == 'admin') {
      _filtered = visibleUsers
          .where((u) => u.role == 'admin' || u.role == 'faculty_admin')
          .toList();
    } else {
      _filtered = visibleUsers.where((u) => u.role == _filterRole).toList();
    }
  }

  bool _canManageUser(UserModel? currentUser, UserModel targetUser) {
    if (currentUser == null) return false;
    if (targetUser.uid == currentUser.uid) return false;

    if (currentUser.isSuperAdmin) {
      return true;
    }

    if (currentUser.isAnyAdmin) {
      return targetUser.isStudent || targetUser.isContributor;
    }

    return false;
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Permanently delete ${user.name}\'s account (${user.roleLabel}) from EduShare?\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Permanently',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteUser(user.uid);
      setState(() {
        _users.removeWhere((u) => u.uid == user.uid);
        _applyFilter();
      });
      _showSnack('${user.name}\'s account permanently deleted.', const Color(0xFFEF4444));
    } catch (e) {
      _showSnack('Failed: $e', const Color(0xFFEF4444));
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser =
        context.select<AuthService, UserModel?>((s) => s.currentUser);

    return Scaffold(
      appBar: AppBar(
        title: Text('Users',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor),
                ),
                child: Text('${_filtered.length} users',
                    style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Column(
              children: [
                // ─── Role filter chips ───────────────────────────────
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _roles.length,
                    itemBuilder: (context, i) {
                      final r = _roles[i];
                      final isSelected = _filterRole == r['value'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _filterRole = r['value']!;
                            _applyFilter();
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : theme.dividerColor,
                                width: 1.5,
                              ),
                            ),
                            child: Text(r['label']!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : null,
                                )),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ─── User list ───────────────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    color: AppTheme.primaryColor,
                    onRefresh: _loadUsers,
                    child: _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people_outline_rounded,
                                    size: 56, color: AppTheme.primaryColor),
                                const SizedBox(height: 14),
                                Text('No users found',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 4),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final user = _filtered[index];
                              final canManage = _canManageUser(currentUser, user);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: _UserCard(
                                  user: user,
                                  canManage: canManage,
                                  onDelete: () => _deleteUser(user),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final bool canManage;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.canManage,
    required this.onDelete,
  });

  Color _roleColor() {
    switch (user.role) {
      case 'super_admin': return const Color(0xFF8B5CF6);
      case 'faculty_admin':
      case 'admin': return AppTheme.primaryColor;
      case 'contributor': return const Color(0xFF10B981);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = user.name.isNotEmpty
        ? user.name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : '?';
    final roleColor = _roleColor();

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: roleColor.withOpacity(0.15),
            child: Text(initials,
                style: TextStyle(
                    color: roleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(user.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 11, color: theme.disabledColor)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: roleColor.withOpacity(0.4)),
                      ),
                      child: Text(user.roleLabel,
                          style: TextStyle(
                              color: roleColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10)),
                    ),
                    const SizedBox(width: 8),
                    Text(user.department,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.delete_forever_outlined,
                  color: Color(0xFFEF4444), size: 20),
              tooltip: 'Delete User',
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
