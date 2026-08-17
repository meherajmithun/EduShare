/// material_model.dart — Flutter model for an academic material resource.
///
/// Matches the JSON shape returned by the Node.js API, including the
/// full department-based approval workflow fields.
class MaterialModel {
  final String id;
  final String title;
  final String description;
  final String type;            // 'notes' | 'assignment' | 'video' | 'pdf'
  final String? fileUrl;        // Cloudinary secure URL (PDF/image/video)
  final String? videoLink;      // YouTube URL (null for Cloudinary videos)
  final String? videoSource;    // 'cloudinary' | 'youtube' | null
  final String? fileName;       // Original filename (for PDF display)
  final int? fileSize;          // File size in bytes
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
    this.videoSource,
    this.fileName,
    this.fileSize,
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

  // ─── Computed helpers ─────────────────────────────────────────────────

  /// True if this material has been approved by admin.
  bool get isApproved => approvalStatus == 'approved' || status == 'approved';

  /// Extract YouTube Video ID from YouTube link
  String? get youtubeVideoId {
    if (videoLink == null || videoLink!.isEmpty) return null;
    final link = videoLink!.trim();
    final regExp = RegExp(
      r'^(?:https?:\/\/)?(?:www\.)?(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([\w-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(link);
    return match?.group(1);
  }

  /// True if this video is stored on YouTube (use YouTube player).
  bool get isYouTube {
    if (type != 'video') return false;
    if (videoSource == 'youtube') return true;
    if (isLegacyYouTube) return true;
    return youtubeVideoId != null;
  }

  /// True if this video was uploaded to Cloudinary (use native video player).
  bool get isCloudinaryVideo {
    if (type != 'video') return false;
    if (videoSource == 'cloudinary') return true;
    if (!isYouTube && fileUrl != null && fileUrl!.isNotEmpty) return true;
    return false;
  }

  /// True if this material is a PDF file (in-app PDF viewer).
  bool get isPdf {
    if (type == 'pdf') return true;
    if (fileName != null && fileName!.toLowerCase().endsWith('.pdf')) return true;
    if (fileUrl != null && fileUrl!.toLowerCase().contains('.pdf')) return true;
    return false;
  }

  /// True if this material is an image file (in-app Image viewer).
  bool get isImage {
    if (isPdf) return false;
    if (fileName != null && fileName!.isNotEmpty) {
      final lowerName = fileName!.toLowerCase();
      if (lowerName.endsWith('.jpg') ||
          lowerName.endsWith('.jpeg') ||
          lowerName.endsWith('.png') ||
          lowerName.endsWith('.webp') ||
          lowerName.endsWith('.gif') ||
          lowerName.endsWith('.bmp')) {
        return true;
      }
    }
    if (fileUrl != null && fileUrl!.isNotEmpty) {
      final lower = fileUrl!.toLowerCase();
      if (lower.contains('.pdf')) return false;
      return lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.webp') ||
          lower.endsWith('.gif') ||
          lower.endsWith('.bmp') ||
          (lower.contains('/image/upload/') && !lower.contains('.pdf'));
    }
    return false;
  }

  /// Playback URL for this video (null if not a valid video material).
  String? get videoPlaybackUrl {
    if (isYouTube) return videoLink;
    if (isCloudinaryVideo) return fileUrl;
    if (type == 'video' && videoLink != null && videoLink!.isNotEmpty) return videoLink;
    if (type == 'video' && fileUrl != null && fileUrl!.isNotEmpty) return fileUrl;
    return null;
  }

  /// True if this is a legacy YouTube-linked video (no videoSource field set).
  bool get isLegacyYouTube {
    if (type != 'video') return false;
    if (videoLink == null || videoLink!.isEmpty) return false;
    final link = videoLink!.toLowerCase();
    return link.contains('youtube.com') || link.contains('youtu.be');
  }

  /// Computed cover thumbnail URL for cards & preview lists.
  String get computedThumbnailUrl {
    // 1. YouTube video thumbnail
    final ytId = youtubeVideoId;
    if (ytId != null && ytId.isNotEmpty) {
      return 'https://img.youtube.com/vi/$ytId/hqdefault.jpg';
    }

    // 2. Cloudinary video / PDF poster frame
    if (fileUrl != null && fileUrl!.isNotEmpty) {
      final url = fileUrl!;
      if (url.contains('cloudinary.com')) {
        if (type == 'video' || url.contains('/video/upload/')) {
          return url.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '.jpg');
        }
        if (isPdf || url.contains('/raw/upload/') || url.contains('/image/upload/')) {
          return url.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '.jpg');
        }
      }
    }

    // 3. Fallback high-quality curated cover images based on type
    switch (type.toLowerCase()) {
      case 'video':
        return 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=500&auto=format&fit=crop&q=80';
      case 'pdf':
        return 'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=500&auto=format&fit=crop&q=80';
      case 'notes':
        return 'https://images.unsplash.com/photo-1517842645767-c639042777db?w=500&auto=format&fit=crop&q=80';
      case 'assignment':
        return 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=500&auto=format&fit=crop&q=80';
      default:
        return 'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=500&auto=format&fit=crop&q=80';
    }
  }

  // ─── JSON serialisation ───────────────────────────────────────────────

  factory MaterialModel.fromJson(Map<String, dynamic> json) {
    return MaterialModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: json['type'] as String? ?? 'notes',
      fileUrl: json['fileUrl'] as String?,
      videoLink: json['videoLink'] as String?,
      videoSource: json['videoSource'] as String?,
      fileName: json['fileName'] as String?,
      fileSize: (json['fileSize'] as num?)?.toInt(),
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
      'videoSource': videoSource,
      'fileName': fileName,
      'fileSize': fileSize,
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
