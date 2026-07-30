/// firestore_service.dart — Data service backed by the Node.js REST API
///
/// Method signatures are IDENTICAL to the previous mock version wherever
/// screens already use them. New Super Admin methods added at the bottom.

import 'dart:typed_data';
import 'package:edushare/core/services/api_client.dart';
import 'package:edushare/models/department_model.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/models/user_model.dart';

class FirestoreService {
  final _api = ApiClient.instance;

  // ─── Users ────────────────────────────────────────────────────────────

  /// Fetch users. Optionally filter by role and/or status.
  Future<List<UserModel>> getUsers({String? role, String? status}) async {
    var path = '/api/users';
    final params = <String>[];
    if (role != null) params.add('role=$role');
    if (status != null) params.add('status=$status');
    if (params.isNotEmpty) path += '?${params.join('&')}';

    final data = await _api.get(path) as List<dynamic>;
    return data.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Update a user's role (admin only).
  Future<void> updateUserRole(String userId, String role) async {
    await _api.put('/api/users/$userId/role', {'role': role});
  }

  /// Deactivate a user account (admin only).
  Future<void> deleteUser(String userId) async {
    await _api.delete('/api/users/$userId');
  }

  // ─── Departments ──────────────────────────────────────────────────────

  Future<List<DepartmentModel>> getDepartments() async {
    final data = await _api.get('/api/departments') as List<dynamic>;
    return data.map((e) => DepartmentModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Courses ──────────────────────────────────────────────────────────

  Future<List<CourseModel>> getCourses(String departmentId) async {
    final data = await _api.get('/api/courses?departmentId=$departmentId') as List<dynamic>;
    return data.map((e) => CourseModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Materials — public browsing ──────────────────────────────────────

  Future<List<MaterialModel>> getApprovedMaterials(String courseId, {String? type}) async {
    var path = '/api/materials?courseId=$courseId';
    if (type != null) path += '&type=$type';
    final data = await _api.get(path) as List<dynamic>;
    return data.map((e) => MaterialModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Materials — admin ────────────────────────────────────────────────

  Future<List<MaterialModel>> getAllMaterials({String? status}) async {
    var path = '/api/admin/materials';
    if (status != null) path += '?status=$status';
    final data = await _api.get(path) as List<dynamic>;
    return data.map((e) => MaterialModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Materials — contributor ──────────────────────────────────────────

  Future<List<MaterialModel>> getMyMaterials(String uid) async {
    final data = await _api.get('/api/materials/my') as List<dynamic>;
    return data.map((e) => MaterialModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Materials — admin approvals ──────────────────────────────────────

  Future<List<MaterialModel>> getPendingMaterials() async {
    final data = await _api.get('/api/admin/pending') as List<dynamic>;
    return data.map((e) => MaterialModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Material upload ──────────────────────────────────────────────────
  //
  // Uses bytes-based multipart upload for cross-platform compatibility.
  // FilePicker must be called with withData: true so bytes is always populated.

  Future<void> uploadMaterial(
    MaterialModel material, {
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    if (fileBytes != null && material.type != 'video') {
      await _api.postMultipartBytes(
        '/api/materials',
        bytes: fileBytes,
        fileName: fileName ?? 'upload',
        fileField: 'file',
        fields: {
          'title': material.title,
          'description': material.description,
          'type': material.type,
          'courseId': material.courseId,
          'departmentId': material.departmentId,
        },
      );
    } else {
      await _api.post('/api/materials', {
        'title': material.title,
        'description': material.description,
        'type': material.type,
        'videoLink': material.videoLink ?? '',
        'courseId': material.courseId,
        'departmentId': material.departmentId,
      });
    }
  }

  Future<void> deleteMaterial(String materialId) async {
    await _api.delete('/api/materials/$materialId');
  }

  /// Approve or reject a material.
  /// [reason] is required when status = 'rejected' and is stored as rejectionReason.
  Future<void> updateMaterialStatus(
    String materialId,
    String status, {
    String? reason,
  }) async {
    if (status == 'approved') {
      await _api.put('/api/admin/approve/$materialId', {});
    } else {
      await _api.put('/api/admin/reject/$materialId', {
        'reason': reason ?? 'No reason provided.',
      });
    }
  }

  // ─── Admin stats ──────────────────────────────────────────────────────

  /// Fetch material + user stats (scoped by department for faculty_admin).
  Future<Map<String, dynamic>> getAdminStats() async {
    final data = await _api.get('/api/admin/stats');
    return data as Map<String, dynamic>;
  }

  // ─── Contributor management (Faculty Admin) ───────────────────────────

  /// Fetch contributors with status = pending in the Faculty Admin's department.
  Future<List<UserModel>> getPendingContributors() async {
    final data = await _api.get('/api/admin/pending-contributors') as List<dynamic>;
    return data.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Approve a pending contributor account.
  Future<void> approveContributor(String id) async {
    await _api.put('/api/admin/contributors/$id/approve', {});
  }

  /// Reject a pending contributor account with an optional reason.
  Future<void> rejectContributor(String id, {String? reason}) async {
    await _api.put(
      '/api/admin/contributors/$id/reject',
      reason != null && reason.trim().isNotEmpty ? {'reason': reason.trim()} : {},
    );
  }

  // ─── Super Admin — Faculty Admin management ───────────────────────────

  Future<List<UserModel>> getPendingFacultyAdmins() async {
    final data = await _api.get('/api/super-admin/faculty-admins/pending') as List<dynamic>;
    return data.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<UserModel>> getAllFacultyAdmins({String? status}) async {
    var path = '/api/super-admin/faculty-admins';
    if (status != null) path += '?status=$status';
    final data = await _api.get(path) as List<dynamic>;
    return data.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> approveFacultyAdmin(String id) async {
    await _api.put('/api/super-admin/faculty-admins/$id/approve', {});
  }

  Future<void> rejectFacultyAdmin(String id, {String? reason}) async {
    await _api.put('/api/super-admin/faculty-admins/$id/reject',
        reason != null && reason.trim().isNotEmpty ? {'reason': reason.trim()} : {});
  }

  Future<void> disableFacultyAdmin(String id) async {
    await _api.put('/api/super-admin/faculty-admins/$id/disable', {});
  }

  Future<void> enableFacultyAdmin(String id) async {
    await _api.put('/api/super-admin/faculty-admins/$id/enable', {});
  }

  Future<void> deleteFacultyAdmin(String id) async {
    await _api.delete('/api/super-admin/faculty-admins/$id');
  }

  /// Super Admin global stats
  Future<Map<String, dynamic>> getSuperAdminStats() async {
    final data = await _api.get('/api/super-admin/stats');
    return data as Map<String, dynamic>;
  }

  /// Super Admin — all users across all roles
  Future<List<UserModel>> getAllUsers({String? role, String? status}) async {
    var path = '/api/super-admin/users';
    final params = <String>[];
    if (role != null) params.add('role=$role');
    if (status != null) params.add('status=$status');
    if (params.isNotEmpty) path += '?${params.join('&')}';

    final data = await _api.get(path) as List<dynamic>;
    return data.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
