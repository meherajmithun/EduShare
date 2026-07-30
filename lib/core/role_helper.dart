import 'package:edushare/models/user_model.dart';

/// Extension on [UserModel] providing clean role-check helpers.
/// Use these throughout the app instead of hardcoded string comparisons.
extension RoleHelper on UserModel {
  // ─── Role checks ───────────────────────────────────────────────────
  bool get isStudent => role == 'student';
  bool get isContributor => role == 'contributor';
  bool get isAdmin => role == 'admin'; // legacy admin
  bool get isFacultyAdmin => role == 'faculty_admin';
  bool get isSuperAdmin => role == 'super_admin';

  // ─── Status checks ─────────────────────────────────────────────────
  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isDisabled => status == 'disabled';
  bool get isRejected => status == 'rejected';

  // ─── Permission helpers ────────────────────────────────────────────

  /// True for roles that can upload materials (active contributor, admin-class roles)
  bool get canUpload =>
      (isContributor && isActive) || isAdmin || isFacultyAdmin || isSuperAdmin;

  /// True for roles that can approve / reject materials
  bool get canApprove => isAdmin || isFacultyAdmin || isSuperAdmin;

  /// True for the Super Admin only (manages Faculty Admin accounts)
  bool get canManageFacultyAdmins => isSuperAdmin;

  /// True for any admin-class role (legacy admin, faculty_admin, super_admin)
  bool get isAnyAdmin => isAdmin || isFacultyAdmin || isSuperAdmin;

  /// Human-readable role label
  String get roleLabel {
    switch (role) {
      case 'student':
        return 'Student';
      case 'contributor':
        return 'Contributor';
      case 'admin':
        return 'Admin (Legacy)';
      case 'faculty_admin':
        return 'Admin';
      case 'super_admin':
        return 'Super Admin';
      default:
        return role;
    }
  }

  /// Human-readable status label
  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Active';
      case 'pending':
        return 'Pending Approval';
      case 'disabled':
        return 'Disabled';
      default:
        return status;
    }
  }
}
