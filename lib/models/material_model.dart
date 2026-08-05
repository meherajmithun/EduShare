/// material_model.dart — Flutter model for an academic material resource.
///
/// Matches the JSON shape returned by the Node.js API, including the
/// full department-based approval workflow fields.
class MaterialModel {
  final String id;
  final String title;
  final String description;
  final String type;            // 'notes' | 'assignment' | 'video'
  final String? fileUrl;        // Cloudinary secure URL (PDF/image)
  final String? videoLink;      // YouTube / Google Drive URL
  final String courseId;
  final String departmentId;
  final String department;      // Denormalised department name
  final String uploadedBy;      // User id (string)
  final String contributorName;

  // ─── Approval workflow ────────────────────────────────────────────────

  /// Canonical approval status: 'pending' | 'approved' | 'rejected'
  final String approvalStatus;

  /// Legacy mirror of approvalStatus — same value, kept for backward compat
  final String status;

  /// ID of the Faculty Admin assigned to review this material
  final String? assignedAdmin;

  /// Denormalised name of the assigned Faculty Admin
  final String? assignedAdminName;

  /// ID of the admin who approved or rejected
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;

  /// Populated when approvalStatus == 'rejected'
  final String? rejectionReason;

  /// Admin review comment — visible to contributor after approve or reject
  final String? reviewComment;

  /// Per-material rating stats (rolled up to contributor avgRating)
  final double avgRating;
  final int totalRatings;

  /// View count
  final int views;

  final DateTime createdAt;

  const MaterialModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.fileUrl,
    this.videoLink,
    required this.courseId,
    required this.departmentId,
    this.department = '',
    required this.uploadedBy,
    required this.contributorName,
    this.approvalStatus = 'pending',
    this.status = 'pending',
    this.assignedAdmin,
    this.assignedAdminName,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.rejectionReason,
    this.reviewComment,
    this.avgRating = 0.0,
    this.totalRatings = 0,
    this.views = 0,
    required this.createdAt,
  });

  // ─── JSON serialisation ───────────────────────────────────────────────

  factory MaterialModel.fromJson(Map<String, dynamic> json) {
    return MaterialModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: json['type'] as String? ?? 'notes',
      fileUrl: json['fileUrl'] as String?,
      videoLink: json['videoLink'] as String?,
      courseId: (json['courseId'] ?? '').toString(),
      departmentId: (json['departmentId'] ?? '').toString(),
      department: json['department'] as String? ?? '',
      uploadedBy: (json['uploadedBy'] ?? '').toString(),
      contributorName: json['contributorName'] as String? ?? 'Anonymous',

      // Use approvalStatus first, fall back to status for legacy records
      approvalStatus: json['approvalStatus'] as String? ??
          json['status'] as String? ?? 'pending',
      status: json['status'] as String? ??
          json['approvalStatus'] as String? ?? 'pending',

      assignedAdmin: json['assignedAdmin']?.toString(),
      assignedAdminName: json['assignedAdminName'] as String?,
      approvedBy: json['approvedBy']?.toString(),
      approvedByName: json['approvedByName'] as String?,
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'].toString())
          : null,
      rejectionReason: json['rejectionReason'] as String?,
      reviewComment: json['reviewComment'] as String?,
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: (json['totalRatings'] as num?)?.toInt() ?? 0,
      views: (json['views'] as num?)?.toInt() ?? 0,

      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'fileUrl': fileUrl,
      'videoLink': videoLink,
      'courseId': courseId,
      'departmentId': departmentId,
      'department': department,
      'uploadedBy': uploadedBy,
      'contributorName': contributorName,
      'approvalStatus': approvalStatus,
      'status': status,
      'assignedAdmin': assignedAdmin,
      'assignedAdminName': assignedAdminName,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'approvedAt': approvedAt?.toIso8601String(),
      'rejectionReason': rejectionReason,
      'reviewComment': reviewComment,
      'avgRating': avgRating,
      'totalRatings': totalRatings,
      'views': views,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Legacy Firestore aliases
  factory MaterialModel.fromMap(Map<String, dynamic> map) =>
      MaterialModel.fromJson(map);
  Map<String, dynamic> toMap() => toJson();
}
