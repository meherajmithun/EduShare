class VideoProgressModel {
  final String id;
  final String userId;
  final String materialId;
  final String courseId;
  final int lastPosition; // seconds
  final int duration; // seconds
  final bool completed;
  final DateTime lastWatchedAt;

  const VideoProgressModel({
    required this.id,
    required this.userId,
    required this.materialId,
    required this.courseId,
    this.lastPosition = 0,
    this.duration = 0,
    this.completed = false,
    required this.lastWatchedAt,
  });

  factory VideoProgressModel.fromJson(Map<String, dynamic> json) {
    return VideoProgressModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      materialId: (json['materialId'] ?? '').toString(),
      courseId: (json['courseId'] ?? '').toString(),
      lastPosition: (json['lastPosition'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      completed: json['completed'] as bool? ?? false,
      lastWatchedAt: json['lastWatchedAt'] != null
          ? DateTime.tryParse(json['lastWatchedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'materialId': materialId,
        'courseId': courseId,
        'lastPosition': lastPosition,
        'duration': duration,
        'completed': completed,
        'lastWatchedAt': lastWatchedAt.toIso8601String(),
      };
}
