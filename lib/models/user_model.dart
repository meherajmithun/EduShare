/// user_model.dart — Flutter model for a registered EduShare user.
///
/// Serialises to/from the JSON envelope returned by the Node.js API.
/// Supports all 5 roles: student, contributor, admin, faculty_admin, super_admin.
class UserModel {
  final String uid;           // MongoDB _id (string)
  final String name;
  final String email;
  final String role;          // 'student' | 'contributor' | 'admin' | 'faculty_admin' | 'super_admin'
  final String status;        // 'active' | 'pending' | 'disabled'
  final String department;
  final String? departmentId;
  final String? studentId;    // Students only — used for alternative login
  final String? facultyId;
  final String? designation;
  final String? bio;
  final String? profilePhotoUrl;
  final double avgRating;
  final int totalRatings;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    this.status = 'active',
    this.departmentId,
    this.studentId,
    this.facultyId,
    this.designation,
    this.bio,
    this.profilePhotoUrl,
    this.avgRating = 0.0,
    this.totalRatings = 0,
    required this.createdAt,
  });

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    String? department,
    String? status,
    String? departmentId,
    String? studentId,
    String? facultyId,
    String? designation,
    String? bio,
    String? profilePhotoUrl,
    double? avgRating,
    int? totalRatings,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      department: department ?? this.department,
      status: status ?? this.status,
      departmentId: departmentId ?? this.departmentId,
      studentId: studentId ?? this.studentId,
      facultyId: facultyId ?? this.facultyId,
      designation: designation ?? this.designation,
      bio: bio ?? this.bio,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      avgRating: avgRating ?? this.avgRating,
      totalRatings: totalRatings ?? this.totalRatings,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ─── JSON serialisation (API ←→ Flutter) ──────────────────────────────

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'student',
      status: json['status'] as String? ?? 'active',
      department: json['department'] as String? ?? '',
      departmentId: json['departmentId']?.toString(),
      studentId: json['studentId'] as String?,
      facultyId: json['facultyId'] as String?,
      designation: json['designation'] as String?,
      bio: json['bio'] as String?,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: (json['totalRatings'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': uid,
      'name': name,
      'email': email,
      'role': role,
      'status': status,
      'department': department,
      if (departmentId != null) 'departmentId': departmentId,
      if (studentId != null) 'studentId': studentId,
      if (facultyId != null) 'facultyId': facultyId,
      if (designation != null) 'designation': designation,
      if (bio != null) 'bio': bio,
      if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
      'avgRating': avgRating,
      'totalRatings': totalRatings,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Firestore legacy aliases (kept for compatibility)
  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel.fromJson(map);
  Map<String, dynamic> toMap() => toJson();
}
