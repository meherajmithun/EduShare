/// contributor_profile_model.dart — Public contributor profile summary model.
class ContributorProfileModel {
  final String id;
  final String name;
  final String email;
  final String department;
  final String? departmentId;
  final String bio;
  final String profilePhotoUrl;
  final double avgRating;
  final int totalRatings;
  final int totalUploads;
  final int approvedUploads;
  final DateTime createdAt;

  const ContributorProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
    this.departmentId,
    required this.bio,
    required this.profilePhotoUrl,
    required this.avgRating,
    required this.totalRatings,
    required this.totalUploads,
    required this.approvedUploads,
    required this.createdAt,
  });

  factory ContributorProfileModel.fromJson(Map<String, dynamic> json) {
    return ContributorProfileModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['name'] as String? ?? 'Contributor',
      email: json['email'] as String? ?? '',
      department: json['department'] as String? ?? '',
      departmentId: json['departmentId']?.toString(),
      bio: json['bio'] as String? ?? '',
      profilePhotoUrl: json['profilePhotoUrl'] as String? ?? '',
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: (json['totalRatings'] as num?)?.toInt() ?? 0,
      totalUploads: (json['totalUploads'] as num?)?.toInt() ?? 0,
      approvedUploads: (json['approvedUploads'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'department': department,
      if (departmentId != null) 'departmentId': departmentId,
      'bio': bio,
      'profilePhotoUrl': profilePhotoUrl,
      'avgRating': avgRating,
      'totalRatings': totalRatings,
      'totalUploads': totalUploads,
      'approvedUploads': approvedUploads,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
