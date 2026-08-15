import 'package:flutter/material.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/models/department_model.dart';

// ─── Colour tokens ────────────────────────────────────────────────────────────
const _kAmber = Color(0xFFF59E0B);
const _kGreen = Color(0xFF10B981);
const _kRed = Color(0xFFEF4444);

/// Super Admin screen — Manage Admin accounts only.
/// Role displayed: always "Admin" (never "Faculty Admin").
/// Tabs: Pending (approve / reject) | All Admins (search, filter, suspend, delete)
class FacultyAdminsScreen extends StatefulWidget {
  const FacultyAdminsScreen({Key? key}) : super(key: key);

  @override
  State<FacultyAdminsScreen> createState() => _FacultyAdminsScreenState();
}

class _FacultyAdminsScreenState extends State<FacultyAdminsScreen>
    with SingleTickerProviderStateMixin {
  final _service = FirestoreService();
  late TabController _tabController;
  final _searchController = TextEditingController();

  List<UserModel> _pending = [];
  List<UserModel> _all = [];
  List<UserModel> _filtered = [];
  bool _loadingPending = true;
  bool _loadingAll = true;
  String _filterStatus = 'all'; // all | pending | active | disabled
  UserModel? _selectedAdmin;
  final Set<String> _processingIds = {};

  // ── Departments state ──────────────────────────────────────────────────────
  List<DepartmentModel> _departments = [];
  bool _loadingDepts = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedAdmin = null);
      }
    });
    _loadPending();
    _loadAll();
    _loadDepartments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadPending() async {
    try {
      final list = await _service.getPendingFacultyAdmins();
      if (mounted) setState(() { _pending = list; _loadingPending = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  Future<void> _loadAll() async {
    try {
      final list = await _service.getAllFacultyAdmins();
      if (mounted) {
        setState(() {
          _all = list;
          _loadingAll = false;
          _applyFilter();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  Future<void> _loadDepartments() async {
    try {
      final list = await _service.getAllDepartmentsAdmin();
      if (mounted) {
        setState(() {
          _departments = list;
          _loadingDepts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDepts = false);
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _all.where((u) {
        final matchStatus = _filterStatus == 'all' || u.status == _filterStatus;
        final matchSearch = query.isEmpty ||
            u.name.toLowerCase().contains(query) ||
            u.email.toLowerCase().contains(query) ||
            (u.department.toLowerCase().contains(query));
        return matchStatus && matchSearch;
      }).toList();
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _approve(UserModel admin) async {
    setState(() => _processingIds.add(admin.uid));
    try {
      await _service.approveFacultyAdmin(admin.uid);
      setState(() {
        _pending.removeWhere((u) => u.uid == admin.uid);
        _processingIds.remove(admin.uid);
        if (_selectedAdmin?.uid == admin.uid) _selectedAdmin = null;
      });
      await _loadAll();
      _showSnack('${admin.name} approved.', _kGreen);
    } catch (e) {
      setState(() => _processingIds.remove(admin.uid));
      _showSnack('Failed: $e', _kRed);
    }
  }

  Future<void> _reject(UserModel admin) async {
    final reason = await _showRejectDialog(admin.name);
    if (reason == null) return;
    setState(() => _processingIds.add(admin.uid));
    try {
      await _service.rejectFacultyAdmin(admin.uid,
          reason: reason.trim().isNotEmpty ? reason.trim() : null);
      setState(() {
        _pending.removeWhere((u) => u.uid == admin.uid);
        _processingIds.remove(admin.uid);
        if (_selectedAdmin?.uid == admin.uid) _selectedAdmin = null;
      });
      _showSnack('${admin.name} rejected.', _kRed);
    } catch (e) {
      setState(() => _processingIds.remove(admin.uid));
      _showSnack('Failed: $e', _kRed);
    }
  }

  Future<void> _suspend(UserModel admin) async {
    final ok = await _confirmDialog(
      'Suspend Admin',
      'Suspend ${admin.name}\'s account? They cannot log in while suspended.',
      label: 'Suspend',
      color: _kAmber,
    );
    if (!ok) return;
    setState(() => _processingIds.add(admin.uid));
    try {
      await _service.disableFacultyAdmin(admin.uid);
      await _loadAll();
      setState(() {
        _processingIds.remove(admin.uid);
        _selectedAdmin = null;
      });
      _showSnack('${admin.name} suspended.', _kAmber);
    } catch (e) {
      setState(() => _processingIds.remove(admin.uid));
      _showSnack('Failed: $e', _kRed);
    }
  }

  Future<void> _activate(UserModel admin) async {
    setState(() => _processingIds.add(admin.uid));
    try {
      await _service.enableFacultyAdmin(admin.uid);
      await _loadAll();
      setState(() {
        _processingIds.remove(admin.uid);
        _selectedAdmin = null;
      });
      _showSnack('${admin.name} reactivated.', _kGreen);
    } catch (e) {
      setState(() => _processingIds.remove(admin.uid));
      _showSnack('Failed: $e', _kRed);
    }
  }

  Future<void> _delete(UserModel admin) async {
    final ok = await _confirmDialog(
      'Delete Account',
      'Permanently delete ${admin.name}\'s Admin account? This cannot be undone.',
      label: 'Delete',
      color: _kRed,
    );
    if (!ok) return;
    setState(() => _processingIds.add(admin.uid));
    try {
      await _service.deleteFacultyAdmin(admin.uid);
      setState(() {
        _all.removeWhere((u) => u.uid == admin.uid);
        _processingIds.remove(admin.uid);
        if (_selectedAdmin?.uid == admin.uid) _selectedAdmin = null;
        _applyFilter();
      });
      _showSnack('${admin.name} deleted.', _kRed);
    } catch (e) {
      setState(() => _processingIds.remove(admin.uid));
      _showSnack('Failed: $e', _kRed);
    }
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  Future<String?> _showRejectDialog(String name) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Registration',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rejecting $name\'s Admin application.'),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Incomplete information',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kRed),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Reject',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<bool> _confirmDialog(String title, String msg,
      {required String label, required Color color}) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(msg),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: color),
                onPressed: () => Navigator.pop(context, true),
                child: Text(label,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
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

  // ── Department Actions & Dialogs ──────────────────────────────────────────

  Future<void> _showEditDeptDialog(DepartmentModel dept) async {
    final nameCtrl = TextEditingController(text: dept.name);
    final codeCtrl = TextEditingController(text: dept.code);
    final descCtrl = TextEditingController(text: dept.description);
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Department', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Department Name *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Code *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Code is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description (Optional)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await _service.updateDepartmentAdmin(
                  dept.id,
                  name: nameCtrl.text.trim(),
                  code: codeCtrl.text.trim().toUpperCase(),
                  description: descCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: _kRed),
                  );
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    codeCtrl.dispose();
    descCtrl.dispose();

    if (updated == true) {
      _showSnack('Department updated.', _kGreen);
      _loadDepartments();
    }
  }

  Future<void> _toggleDeptActive(DepartmentModel dept) async {
    try {
      if (dept.isActive) {
        await _service.deactivateDepartmentAdmin(dept.id);
        _showSnack('${dept.name} deactivated.', _kAmber);
      } else {
        await _service.activateDepartmentAdmin(dept.id);
        _showSnack('${dept.name} activated.', _kGreen);
      }
      _loadDepartments();
    } catch (e) {
      _showSnack('Failed: $e', _kRed);
    }
  }

  Future<void> _deleteDept(DepartmentModel dept) async {
    final ok = await _confirmDialog(
      'Delete Department',
      'Permanently delete "${dept.name}"? Courses and users in this department may be affected.',
      label: 'Delete',
      color: _kRed,
    );
    if (!ok) return;

    try {
      await _service.deleteDepartmentAdmin(dept.id);
      _showSnack('${dept.name} deleted.', _kRed);
      _loadDepartments();
    } catch (e) {
      _showSnack('Failed: $e', _kRed);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── AppBar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).canPop() ? Navigator.of(context).pop() : null,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isDark
                                ? AppTheme.darkBorder
                                : AppTheme.lightBorder),
                      ),
                      child: Icon(Icons.chevron_left_rounded,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ADMIN CONSOLE',
                            style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor)),
                        Text('Manage Admins',
                            style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold, fontSize: 20)),
                      ],
                    ),
                  ),
                  // Invite (add) button
                  GestureDetector(
                    onTap: () => _showSnack(
                        'Send invite link to a new Admin via email (coming soon)',
                        AppTheme.primaryColor),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Search Bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _applyFilter(),
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search name, email, or department...',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                        size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilter();
                            })
                        : null,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Tabs ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color:
                          isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                  indicator: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.hourglass_top_rounded, size: 14),
                          const SizedBox(width: 4),
                          Text('Pending (${_pending.length})', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_rounded, size: 14),
                          const SizedBox(width: 4),
                          Text('All (${_all.length})', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.domain_rounded, size: 14),
                          const SizedBox(width: 4),
                          Text('Depts (${_departments.length})', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 4),

            // ── Tab Body ────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // PENDING TAB
                  _PendingTab(
                    pending: _pending,
                    isLoading: _loadingPending,
                    processingIds: _processingIds,
                    selectedAdmin: _selectedAdmin,
                    isDark: isDark,
                    onSelect: (u) => setState(() => _selectedAdmin = u),
                    onApprove: _approve,
                    onReject: _reject,
                    onRefresh: _loadPending,
                  ),
                  // ALL ADMINS TAB
                  _AllTab(
                    admins: _filtered,
                    isLoading: _loadingAll,
                    processingIds: _processingIds,
                    selectedAdmin: _selectedAdmin,
                    isDark: isDark,
                    filterStatus: _filterStatus,
                    onFilterChanged: (s) {
                      setState(() => _filterStatus = s);
                      _applyFilter();
                    },
                    onSelect: (u) => setState(() => _selectedAdmin = u),
                    onSuspend: _suspend,
                    onActivate: _activate,
                    onDelete: _delete,
                    onRefresh: _loadAll,
                  ),
                  // DEPARTMENTS TAB
                  _DepartmentsTab(
                    departments: _departments,
                    isLoading: _loadingDepts,
                    isDark: isDark,
                    onRefresh: _loadDepartments,
                    onEditDept: _showEditDeptDialog,
                    onToggleActive: _toggleDeptActive,
                    onDeleteDept: _deleteDept,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Pending Tab
// ═══════════════════════════════════════════════════════════════════════════════

class _PendingTab extends StatelessWidget {
  final List<UserModel> pending;
  final bool isLoading;
  final Set<String> processingIds;
  final UserModel? selectedAdmin;
  final bool isDark;
  final ValueChanged<UserModel?> onSelect;
  final Future<void> Function(UserModel) onApprove;
  final Future<void> Function(UserModel) onReject;
  final Future<void> Function() onRefresh;

  const _PendingTab({
    required this.pending,
    required this.isLoading,
    required this.processingIds,
    required this.selectedAdmin,
    required this.isDark,
    required this.onSelect,
    required this.onApprove,
    required this.onReject,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Detail card (if selected)
          if (selectedAdmin != null && pending.any((u) => u.uid == selectedAdmin!.uid))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _AdminDetailCard(
                  admin: selectedAdmin!,
                  isDark: isDark,
                  isProcessing: processingIds.contains(selectedAdmin!.uid),
                  onApprove: () => onApprove(selectedAdmin!),
                  onReject: () => onReject(selectedAdmin!),
                  onClose: () => onSelect(null),
                ),
              ),
            ),

          if (pending.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(
                icon: Icons.hourglass_disabled_rounded,
                title: 'No Pending Admins',
                subtitle: 'All admin registrations have been reviewed.',
                isDark: isDark,
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text('PENDING REGISTRATIONS',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary)),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _AdminListTile(
                    admin: pending[i],
                    isDark: isDark,
                    isSelected: selectedAdmin?.uid == pending[i].uid,
                    isProcessing: processingIds.contains(pending[i].uid),
                    onTap: () => onSelect(
                        selectedAdmin?.uid == pending[i].uid ? null : pending[i]),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionButton(
                          label: 'Approve',
                          color: _kGreen,
                          isDark: isDark,
                          onTap: () => onApprove(pending[i]),
                          isLoading: processingIds.contains(pending[i].uid),
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          label: 'Reject',
                          color: _kRed,
                          isDark: isDark,
                          onTap: () => onReject(pending[i]),
                          isLoading: processingIds.contains(pending[i].uid),
                        ),
                      ],
                    ),
                  ),
                ),
                childCount: pending.length,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// All Admins Tab
// ═══════════════════════════════════════════════════════════════════════════════

class _AllTab extends StatelessWidget {
  final List<UserModel> admins;
  final bool isLoading;
  final Set<String> processingIds;
  final UserModel? selectedAdmin;
  final bool isDark;
  final String filterStatus;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<UserModel?> onSelect;
  final Future<void> Function(UserModel) onSuspend;
  final Future<void> Function(UserModel) onActivate;
  final Future<void> Function(UserModel) onDelete;
  final Future<void> Function() onRefresh;

  const _AllTab({
    required this.admins,
    required this.isLoading,
    required this.processingIds,
    required this.selectedAdmin,
    required this.isDark,
    required this.filterStatus,
    required this.onFilterChanged,
    required this.onSelect,
    required this.onSuspend,
    required this.onActivate,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Status filter chips ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in [
                      {'value': 'all', 'label': 'All'},
                      {'value': 'pending', 'label': 'Pending'},
                      {'value': 'active', 'label': 'Active'},
                      {'value': 'disabled', 'label': 'Disabled'},
                    ]) ...[
                      _FilterChip(
                        label: f['label']!,
                        isSelected: filterStatus == f['value'],
                        isDark: isDark,
                        onTap: () => onFilterChanged(f['value']!),
                      ),
                      const SizedBox(width: 8),
                    ]
                  ],
                ),
              ),
            ),
          ),

          // ── Selected Admin detail card ─────────────────────────
          if (selectedAdmin != null &&
              admins.any((u) => u.uid == selectedAdmin!.uid))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _AdminDetailCard(
                  admin: selectedAdmin!,
                  isDark: isDark,
                  isProcessing: processingIds.contains(selectedAdmin!.uid),
                  onApprove: selectedAdmin!.status == 'disabled'
                      ? () => onActivate(selectedAdmin!)
                      : null,
                  onSuspend: selectedAdmin!.status == 'active'
                      ? () => onSuspend(selectedAdmin!)
                      : null,
                  onDelete: () => onDelete(selectedAdmin!),
                  onClose: () => onSelect(null),
                ),
              ),
            ),

          // ── Directory label ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text('DIRECTORY LIST',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary)),
            ),
          ),

          if (admins.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(
                icon: Icons.people_outline_rounded,
                title: 'No Admins Found',
                subtitle: 'Try adjusting the filter or search.',
                isDark: isDark,
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final admin = admins[i];
                  Widget trailing;
                  if (admin.status == 'pending') {
                    trailing = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionButton(
                          label: 'Approve',
                          color: _kGreen,
                          isDark: isDark,
                          onTap: () => onActivate(admin),
                          isLoading: processingIds.contains(admin.uid),
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          label: 'Delete',
                          color: _kRed,
                          isDark: isDark,
                          onTap: () => onDelete(admin),
                          isLoading: processingIds.contains(admin.uid),
                        ),
                      ],
                    );
                  } else if (admin.status == 'active') {
                    trailing = _ActionButton(
                      label: 'Suspend',
                      color: _kAmber,
                      isDark: isDark,
                      onTap: () => onSuspend(admin),
                      isLoading: processingIds.contains(admin.uid),
                    );
                  } else {
                    trailing = _ActionButton(
                      label: 'Activate',
                      color: _kGreen,
                      isDark: isDark,
                      onTap: () => onActivate(admin),
                      isLoading: processingIds.contains(admin.uid),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _AdminListTile(
                      admin: admin,
                      isDark: isDark,
                      isSelected: selectedAdmin?.uid == admin.uid,
                      isProcessing: processingIds.contains(admin.uid),
                      onTap: () => onSelect(
                          selectedAdmin?.uid == admin.uid ? null : admin),
                      trailing: trailing,
                    ),
                  );
                },
                childCount: admins.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

// ─── Admin Detail Card (Figma top card when selected) ─────────────────────────

class _AdminDetailCard extends StatelessWidget {
  final UserModel admin;
  final bool isDark;
  final bool isProcessing;
  final VoidCallback? onApprove;
  final VoidCallback? onSuspend;
  final VoidCallback? onReject;
  final VoidCallback? onDelete;
  final VoidCallback onClose;

  const _AdminDetailCard({
    required this.admin,
    required this.isDark,
    required this.isProcessing,
    this.onApprove,
    this.onSuspend,
    this.onReject,
    this.onDelete,
    required this.onClose,
  });

  Color get _statusColor {
    switch (admin.status) {
      case 'active': return _kGreen;
      case 'pending': return _kAmber;
      case 'disabled': return _kRed;
      default: return AppTheme.darkTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = admin.name.isNotEmpty
        ? admin.name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : 'A';
    final photoUrl = admin.profilePhotoUrl;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: photoUrl == null || photoUrl.isEmpty
                      ? const LinearGradient(
                          colors: [AppTheme.primaryColor, AppTheme.accentColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)
                      : null,
                  image: photoUrl != null && photoUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(photoUrl),
                          fit: BoxFit.cover,
                          onError: (_, __) {})
                      : null,
                  border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.5), width: 2),
                ),
                child: photoUrl == null || photoUrl.isEmpty
                    ? Center(
                        child: Text(initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(admin.name,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('ADMIN',
                              style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                              admin.status[0].toUpperCase() +
                                  admin.status.substring(1),
                              style: TextStyle(
                                  color: _statusColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${admin.email} • ${admin.department}',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onClose,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Action buttons row
          Row(
            children: [
              if (onApprove != null)
                Expanded(
                  child: _DetailActionBtn(
                    label: 'Activate',
                    icon: Icons.check_circle_outline_rounded,
                    color: _kGreen,
                    isLoading: isProcessing,
                    onTap: onApprove!,
                  ),
                ),
              if (onSuspend != null) ...[
                if (onApprove != null) const SizedBox(width: 10),
                Expanded(
                  child: _DetailActionBtn(
                    label: 'Suspend',
                    icon: Icons.lock_outline_rounded,
                    color: _kAmber,
                    isLoading: isProcessing,
                    onTap: onSuspend!,
                  ),
                ),
              ],
              if (onReject != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _DetailActionBtn(
                    label: 'Reject',
                    icon: Icons.cancel_outlined,
                    color: _kRed,
                    isLoading: isProcessing,
                    onTap: onReject!,
                  ),
                ),
              ],
              if (onDelete != null) ...[
                const SizedBox(width: 10),
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: _kRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kRed.withValues(alpha: 0.5)),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: _kRed, size: 18),
                    onPressed: isProcessing ? null : onDelete,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Admin List Tile ──────────────────────────────────────────────────────────

class _AdminListTile extends StatelessWidget {
  final UserModel admin;
  final bool isDark;
  final bool isSelected;
  final bool isProcessing;
  final VoidCallback onTap;
  final Widget trailing;

  const _AdminListTile({
    required this.admin,
    required this.isDark,
    required this.isSelected,
    required this.isProcessing,
    required this.onTap,
    required this.trailing,
  });

  Color get _statusColor {
    switch (admin.status) {
      case 'active': return _kGreen;
      case 'pending': return _kAmber;
      case 'disabled': return _kRed;
      default: return AppTheme.darkTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = admin.name.isNotEmpty
        ? admin.name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : 'A';
    final photoUrl = admin.profilePhotoUrl;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : (isDark ? AppTheme.darkCard : AppTheme.lightCard),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.5)
                  : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: photoUrl == null || photoUrl.isEmpty
                    ? const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.accentColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)
                    : null,
                image: photoUrl != null && photoUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(photoUrl),
                        fit: BoxFit.cover,
                        onError: (_, __) {})
                    : null,
              ),
              child: photoUrl == null || photoUrl.isEmpty
                  ? Center(
                      child: Text(initials,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)))
                  : null,
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(admin.name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                            admin.status[0].toUpperCase() +
                                admin.status.substring(1),
                            style: TextStyle(
                                color: _statusColor,
                                fontSize: 8,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${admin.department} Dept.',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : (isDark ? AppTheme.darkCard : AppTheme.lightCard),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.isDark,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: isLoading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: color))
            : Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ─── Detail Action Button ─────────────────────────────────────────────────────

class _DetailActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _DetailActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 64,
                color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DEPARTMENTS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _DepartmentsTab extends StatelessWidget {
  final List<DepartmentModel> departments;
  final bool isLoading;
  final bool isDark;
  final Future<void> Function() onRefresh;
  final void Function(DepartmentModel) onEditDept;
  final void Function(DepartmentModel) onToggleActive;
  final void Function(DepartmentModel) onDeleteDept;

  const _DepartmentsTab({
    required this.departments,
    required this.isLoading,
    required this.isDark,
    required this.onRefresh,
    required this.onEditDept,
    required this.onToggleActive,
    required this.onDeleteDept,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Header count
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${departments.length} Department${departments.length == 1 ? '' : 's'}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (departments.isEmpty)
            _EmptyState(
              icon: Icons.domain_disabled_rounded,
              title: 'No Departments Found',
              subtitle: 'Use the "Add Department" action on your Super Admin Dashboard to create a department.',
              isDark: isDark,
            )
          else
            ...departments.map((dept) => _buildDeptCard(context, dept)),
        ],
      ),
    );
  }

  Widget _buildDeptCard(BuildContext context, DepartmentModel dept) {
    final theme = Theme.of(context);
    final isActive = dept.isActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    dept.code,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isActive ? _kGreen : _kRed).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                        size: 12,
                        color: isActive ? _kGreen : _kRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isActive ? _kGreen : _kRed,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit Department',
                  onPressed: () => onEditDept(dept),
                ),
                IconButton(
                  icon: Icon(
                    isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                    color: isActive ? _kAmber : _kGreen,
                  ),
                  tooltip: isActive ? 'Deactivate' : 'Activate',
                  onPressed: () => onToggleActive(dept),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _kRed),
                  tooltip: 'Delete',
                  onPressed: () => onDeleteDept(dept),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              dept.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (dept.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                dept.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

