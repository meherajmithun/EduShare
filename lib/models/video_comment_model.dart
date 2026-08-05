class VideoCommentModel {
  final String id;
  final String materialId;
  final String userId;
  final String userName;
  final String userPhoto;
  final String comment;
  final DateTime createdAt;

  const VideoCommentModel({
    required this.id,
    required this.materialId,
    required this.userId,
    required this.userName,
    this.userPhoto = '',
    required this.comment,
    required this.createdAt,
  });

  factory VideoCommentModel.fromJson(Map<String, dynamic> json) {
    return VideoCommentModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      materialId: (json['materialId'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      userName: json['userName'] as String? ?? 'Anonymous',
      userPhoto: json['userPhoto'] as String? ?? '',
      comment: json['comment'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'materialId': materialId,
        'userId': userId,
        'userName': userName,
        'userPhoto': userPhoto,
        'comment': comment,
        'createdAt': createdAt.toIso8601String(),
      };
}
