/// contributor_profile_model.dart — Public contributor profile summary model.
/// Extended with follow counts, download totals, designation, and verified badge.
class ContributorProfileModel {
  final String id;
  final String name;
  final String email;
  final String department;
  final String? departmentId;
  final String designation;
  final String bio;
  final String profilePhotoUrl;
  final double avgRating;
  final int totalRatings;
  final int totalUploads;
  final int approvedUploads;
  final int totalDownloads;
  final int followerCount;
  final int followingCount;
  final bool isFollowing;
  final bool isVerified;
  final DateTime createdAt;

  const ContributorProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
    this.departmentId,
    this.designation = '',
    required this.bio,
    required this.profilePhotoUrl,
    required this.avgRating,
    required this.totalRatings,
    required this.totalUploads,
    required this.approvedUploads,
    this.totalDownloads = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.isVerified = false,
    required this.createdAt,
  });

  factory ContributorProfileModel.fromJson(Map<String, dynamic> json) {
    return ContributorProfileModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['name'] as String? ?? 'Contributor',
      email: json['email'] as String? ?? '',
      department: json['department'] as String? ?? '',
      departmentId: json['departmentId']?.toString(),
      designation: json['designation'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      profilePhotoUrl: json['profilePhotoUrl'] as String? ?? '',
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: (json['totalRatings'] as num?)?.toInt() ?? 0,
      totalUploads: (json['totalUploads'] as num?)?.toInt() ?? 0,
      approvedUploads: (json['approvedUploads'] as num?)?.toInt() ?? 0,
      totalDownloads: (json['totalDownloads'] as num?)?.toInt() ?? 0,
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
      isFollowing: json['isFollowing'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  ContributorProfileModel copyWith({
    bool? isFollowing,
    int? followerCount,
  }) {
    return ContributorProfileModel(
      id: id,
      name: name,
      email: email,
      department: department,
      departmentId: departmentId,
      designation: designation,
      bio: bio,
      profilePhotoUrl: profilePhotoUrl,
      avgRating: avgRating,
      totalRatings: totalRatings,
      totalUploads: totalUploads,
      approvedUploads: approvedUploads,
      totalDownloads: totalDownloads,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isVerified: isVerified,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'department': department,
      if (departmentId != null) 'departmentId': departmentId,
      'designation': designation,
      'bio': bio,
      'profilePhotoUrl': profilePhotoUrl,
      'avgRating': avgRating,
      'totalRatings': totalRatings,
      'totalUploads': totalUploads,
      'approvedUploads': approvedUploads,
      'totalDownloads': totalDownloads,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'isFollowing': isFollowing,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
