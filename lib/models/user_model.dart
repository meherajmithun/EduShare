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
  final String? facultyId;
  final String? designation;
  final String? bio;
  final String? profilePhotoUrl;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    this.status = 'active',
    this.departmentId,
    this.facultyId,
    this.designation,
    this.bio,
    this.profilePhotoUrl,
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
    String? facultyId,
    String? designation,
    String? bio,
    String? profilePhotoUrl,
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
      facultyId: facultyId ?? this.facultyId,
      designation: designation ?? this.designation,
      bio: bio ?? this.bio,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
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
      facultyId: json['facultyId'] as String?,
      designation: json['designation'] as String?,
      bio: json['bio'] as String?,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
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
      if (facultyId != null) 'facultyId': facultyId,
      if (designation != null) 'designation': designation,
      if (bio != null) 'bio': bio,
      if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Firestore legacy aliases (kept for compatibility)
  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel.fromJson(map);
  Map<String, dynamic> toMap() => toJson();
}
