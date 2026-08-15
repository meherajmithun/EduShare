/// student_course_progress_model.dart — Model for student course progress
class StudentCourseProgressModel {
  final String id;
  final String name;
  final String code;
  final String departmentId;
  final String instructor;
  final int progressPercentage;
  final int completedVideos;
  final int totalVideos;
  final int lastPosition;
  final int duration;
  final String? lastWatchedVideoId;
  final String? lastWatchedVideoTitle;
  final DateTime lastWatchedAt;

  const StudentCourseProgressModel({
    required this.id,
    required this.name,
    required this.code,
    required this.departmentId,
    required this.instructor,
    required this.progressPercentage,
    required this.completedVideos,
    required this.totalVideos,
    required this.lastPosition,
    required this.duration,
    this.lastWatchedVideoId,
    this.lastWatchedVideoTitle,
    required this.lastWatchedAt,
  });

  bool get isCompleted => progressPercentage >= 100 || (completedVideos == totalVideos && totalVideos > 0);

  factory StudentCourseProgressModel.fromJson(Map<String, dynamic> json) {
    return StudentCourseProgressModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['name'] as String? ?? 'Course',
      code: json['code'] as String? ?? '',
      departmentId: (json['departmentId'] ?? '').toString(),
      instructor: json['instructor'] as String? ?? 'Faculty Instructor',
      progressPercentage: (json['progressPercentage'] as num?)?.toInt() ?? 0,
      completedVideos: (json['completedVideos'] as num?)?.toInt() ?? 0,
      totalVideos: (json['totalVideos'] as num?)?.toInt() ?? 0,
      lastPosition: (json['lastPosition'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      lastWatchedVideoId: json['lastWatchedVideoId'] as String?,
      lastWatchedVideoTitle: json['lastWatchedVideoTitle'] as String?,
      lastWatchedAt: json['lastWatchedAt'] != null
          ? DateTime.tryParse(json['lastWatchedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'departmentId': departmentId,
        'instructor': instructor,
        'progressPercentage': progressPercentage,
        'completedVideos': completedVideos,
        'totalVideos': totalVideos,
        'lastPosition': lastPosition,
        'duration': duration,
        'lastWatchedVideoId': lastWatchedVideoId,
        'lastWatchedVideoTitle': lastWatchedVideoTitle,
        'lastWatchedAt': lastWatchedAt.toIso8601String(),
      };
}
