/// notification_model.dart — Flutter model for an in-app notification.
class NotificationModel {
  final String id;
  final String recipientId;
  final String senderId;
  final String senderName;
  final String title;
  final String message;

  /// 'upload_assigned' | 'material_approved' | 'material_rejected'
  final String type;

  final String? materialId;
  final String? materialTitle;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.recipientId,
    required this.senderId,
    required this.senderName,
    required this.title,
    required this.message,
    required this.type,
    this.materialId,
    this.materialTitle,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      recipientId: (json['recipient'] ?? '').toString(),
      senderId: (json['sender'] ?? '').toString(),
      senderName: json['senderName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? '',
      materialId: json['materialId']?.toString(),
      materialTitle: json['materialTitle'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      recipientId: recipientId,
      senderId: senderId,
      senderName: senderName,
      title: title,
      message: message,
      type: type,
      materialId: materialId,
      materialTitle: materialTitle,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  bool get isApproval => type == 'material_approved' || type == 'admin_approved' || type == 'contributor_approved';
  bool get isRejection => type == 'material_rejected' || type == 'admin_rejected' || type == 'contributor_rejected';
  bool get isAssignment => type == 'upload_assigned';
  bool get isPublished => type == 'material_published';
  bool get isRating => type == 'rating_submitted' || type == 'rating_updated';
  bool get isRegistration => type == 'admin_registered' || type == 'contributor_registered';
}
