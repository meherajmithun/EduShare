/// firestore_service.dart — Data service backed by the Node.js REST API
///
/// Method signatures are IDENTICAL to the previous mock version wherever
/// screens already use them. New Super Admin methods added at the bottom.

import 'dart:typed_data';
import 'package:edushare/core/services/api_client.dart';
import 'package:edushare/models/department_model.dart';
import 'package:edushare/models/course_model.dart';
import 'package:edushare/models/material_model.dart';
import 'package:edushare/models/material_rating_model.dart';
import 'package:edushare/models/user_model.dart';
import 'package:edushare/models/rating_model.dart';
import 'package:edushare/models/contributor_profile_model.dart';

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

  /// Fetch ACTIVE courses for a department (used by students & contributors).
  Future<List<CourseModel>> getCourses(String departmentId) async {
    final data = await _api.get('/api/courses?departmentId=$departmentId&status=active') as List<dynamic>;
    return data.map((e) => CourseModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Fetch ALL courses (active + inactive) for a department — for admin management screens.
  Future<List<CourseModel>> getCoursesAdmin(String departmentId) async {
    final data = await _api.get(
      '/api/courses?departmentId=$departmentId&includeAll=true',
    ) as List<dynamic>;
    return data.map((e) => CourseModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Create a new course. Faculty Admin's departmentId is auto-filled by the backend.
  Future<CourseModel> createCourse({
    required String name,
    required String code,
    String? departmentId,
    String semester = '',
    String credit = '3',
  }) async {
    final data = await _api.post('/api/courses', {
      'name': name,
      'code': code,
      if (departmentId != null) 'departmentId': departmentId,
      'semester': semester,
      'credit': num.tryParse(credit) ?? 3,
    });
    return CourseModel.fromJson(data as Map<String, dynamic>);
  }

  /// Update an existing course.
  Future<CourseModel> updateCourse(
    String courseId, {
    required String name,
    required String code,
    String semester = '',
    String credit = '3',
    String status = 'active',
  }) async {
    final data = await _api.put('/api/courses/$courseId', {
      'name': name,
      'code': code,
      'semester': semester,
      'credit': num.tryParse(credit) ?? 3,
      'status': status,
    });
    return CourseModel.fromJson(data as Map<String, dynamic>);
  }

  /// Toggle active/inactive status of a course.
  Future<CourseModel> toggleCourseStatus(String courseId) async {
    final data = await _api.patch('/api/courses/$courseId/status', {});
    return CourseModel.fromJson(data as Map<String, dynamic>);
  }

  /// Delete a course permanently.
  Future<void> deleteCourse(String courseId) async {
    await _api.delete('/api/courses/$courseId');
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
    String? videoSource, // 'cloudinary' | 'youtube' | null
  }) async {
    final isYouTubeUpload =
        material.type == 'video' && (videoSource ?? material.videoSource) == 'youtube';
    final isCloudinaryVideoUpload =
        material.type == 'video' && (videoSource ?? material.videoSource) == 'cloudinary';

    if (isYouTubeUpload) {
      // YouTube: JSON body, no file
      await _api.post('/api/materials', {
        'title': material.title,
        'description': material.description,
        'type': material.type,
        'videoSource': 'youtube',
        'videoLink': material.videoLink ?? '',
        'courseId': material.courseId,
        'departmentId': material.departmentId,
      });
    } else if (fileBytes != null) {
      // File upload (Cloudinary video OR document/PDF)
      final extraFields = <String, String>{
        'title': material.title,
        'description': material.description,
        'type': material.type,
        'courseId': material.courseId,
        'departmentId': material.departmentId,
      };
      if (isCloudinaryVideoUpload) {
        extraFields['videoSource'] = 'cloudinary';
      }

      await _api.postMultipartBytes(
        '/api/materials',
        bytes: fileBytes,
        fileName: fileName ?? 'upload',
        fileField: 'file',
        fields: extraFields,
      );
    } else {
      // Fallback JSON (e.g. legacy or no file selected — should not normally reach here)
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
  /// [reason] is required when status = 'rejected'.
  /// [reviewComment] is optional admin feedback visible to the contributor.
  Future<void> updateMaterialStatus(
    String materialId,
    String status, {
    String? reason,
    String? reviewComment,
  }) async {
    if (status == 'approved') {
      await _api.put('/api/admin/approve/$materialId', {
        if (reviewComment != null && reviewComment.trim().isNotEmpty)
          'reviewComment': reviewComment.trim(),
      });
    } else {
      await _api.put('/api/admin/reject/$materialId', {
        'reason': reason ?? 'No reason provided.',
        if (reviewComment != null && reviewComment.trim().isNotEmpty)
          'reviewComment': reviewComment.trim(),
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

  // ─── Contributor Rating System ─────────────────────────────────────────

  /// Fetch public contributor profile
  Future<ContributorProfileModel> getContributorProfile(String id) async {
    final data = await _api.get('/api/contributors/$id/profile');
    return ContributorProfileModel.fromJson(data as Map<String, dynamic>);
  }

  /// Fetch approved materials uploaded by a specific contributor
  Future<List<MaterialModel>> getContributorMaterials(String id) async {
    final data = await _api.get('/api/contributors/$id/materials') as List<dynamic>;
    return data.map((e) => MaterialModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Fetch ratings for a contributor + current user's own rating
  Future<Map<String, dynamic>> getContributorRatings(String id) async {
    final data = await _api.get('/api/contributors/$id/ratings') as Map<String, dynamic>;
    final ratingsList = (data['ratings'] as List<dynamic>? ?? [])
        .map((e) => RatingModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final myRating = data['myRating'] != null
        ? RatingModel.fromJson(data['myRating'] as Map<String, dynamic>)
        : null;

    return {
      'ratings': ratingsList,
      'myRating': myRating,
    };
  }

  /// Submit rating for a contributor (students only)
  Future<RatingModel> addRating(String contributorId, int stars, {String? review}) async {
    final data = await _api.post('/api/contributors/$contributorId/ratings', {
      'stars': stars,
      if (review != null && review.trim().isNotEmpty) 'review': review.trim(),
    });
    return RatingModel.fromJson(data as Map<String, dynamic>);
  }

  /// Update an existing rating (students only)
  Future<RatingModel> updateRating(String contributorId, int stars, {String? review}) async {
    final data = await _api.put('/api/contributors/$contributorId/ratings', {
      'stars': stars,
      if (review != null) 'review': review.trim(),
    });
    return RatingModel.fromJson(data as Map<String, dynamic>);
  }

  /// Delete an existing rating (students only)
  Future<void> deleteRating(String contributorId) async {
    await _api.delete('/api/contributors/$contributorId/ratings');
  }

  // ─── Material Rating System ────────────────────────────────────────────

  /// Fetch ratings for a specific material + current user's own rating.
  Future<Map<String, dynamic>> getMaterialRatings(String materialId) async {
    final data = await _api.get('/api/materials/$materialId/ratings') as Map<String, dynamic>;
    final ratingsList = (data['ratings'] as List<dynamic>? ?? [])
        .map((e) => MaterialRatingModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final myRating = data['myRating'] != null
        ? MaterialRatingModel.fromJson(data['myRating'] as Map<String, dynamic>)
        : null;
    return {
      'ratings': ratingsList,
      'myRating': myRating,
      'avgRating': (data['avgRating'] as num?)?.toDouble() ?? 0.0,
      'totalRatings': (data['totalRatings'] as num?)?.toInt() ?? 0,
    };
  }

  /// Submit a new rating for a material (students only).
  Future<MaterialRatingModel> addMaterialRating(
    String materialId,
    int stars, {
    String? review,
  }) async {
    final data = await _api.post('/api/materials/$materialId/ratings', {
      'stars': stars,
      if (review != null && review.trim().isNotEmpty) 'review': review.trim(),
    });
    return MaterialRatingModel.fromJson(data as Map<String, dynamic>);
  }

  /// Update the student's existing rating for a material.
  Future<MaterialRatingModel> updateMaterialRating(
    String materialId,
    int stars, {
    String? review,
  }) async {
    final data = await _api.put('/api/materials/$materialId/ratings', {
      'stars': stars,
      if (review != null) 'review': review.trim(),
    });
    return MaterialRatingModel.fromJson(data as Map<String, dynamic>);
  }

  /// Delete the student's own rating for a material.
  Future<void> deleteMaterialRating(String materialId) async {
    await _api.delete('/api/materials/$materialId/ratings');
  }

  // ─── Video Learning System ─────────────────────────────────────────────

  /// Increment video view counter
  Future<void> incrementVideoView(String materialId) async {
    try {
      await _api.post('/api/videos/$materialId/view', {});
    } catch (_) {}
  }

  /// Save video playback position & completion status
  Future<void> saveVideoProgress({
    required String materialId,
    required String courseId,
    required int lastPosition,
    required int duration,
    bool completed = false,
  }) async {
    try {
      await _api.post('/api/videos/progress', {
        'materialId': materialId,
        'courseId': courseId,
        'lastPosition': lastPosition,
        'duration': duration,
        'completed': completed,
      });
    } catch (_) {}
  }

  /// Fetch all video progress records for a course
  Future<List<dynamic>> getCourseVideoProgress(String courseId) async {
    try {
      final data = await _api.get('/api/videos/progress/$courseId') as List<dynamic>;
      return data;
    } catch (_) {
      return [];
    }
  }

  /// Fetch continue watching items
  Future<List<Map<String, dynamic>>> getContinueWatching() async {
    try {
      final data = await _api.get('/api/videos/continue-watching') as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Fetch watch history
  Future<List<Map<String, dynamic>>> getWatchHistory() async {
    try {
      final data = await _api.get('/api/videos/history') as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Fetch bookmarked videos
  Future<List<Map<String, dynamic>>> getBookmarks() async {
    try {
      final data = await _api.get('/api/videos/bookmarks') as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Bookmark a video
  Future<void> addBookmark(String materialId, String courseId) async {
    await _api.post('/api/videos/bookmark/$materialId', {'courseId': courseId});
  }

  /// Remove bookmark
  Future<void> removeBookmark(String materialId) async {
    await _api.delete('/api/videos/bookmark/$materialId');
  }

  /// Fetch comments for a video
  Future<List<dynamic>> getVideoComments(String materialId) async {
    final data = await _api.get('/api/videos/$materialId/comments') as List<dynamic>;
    return data;
  }

  /// Post a comment for a video
  Future<Map<String, dynamic>> addVideoComment(String materialId, String comment) async {
    final data = await _api.post('/api/videos/$materialId/comments', {
      'comment': comment,
    });
    return data as Map<String, dynamic>;
  }
}

