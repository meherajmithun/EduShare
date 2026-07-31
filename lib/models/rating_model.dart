/// rating_model.dart — Flutter model for a contributor rating.
class RatingModel {
  final String id;
  final String contributorId;
  final String ratedById;
  final String ratedByName;
  final int stars;
  final String review;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RatingModel({
    required this.id,
    required this.contributorId,
    required this.ratedById,
    required this.ratedByName,
    required this.stars,
    required this.review,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      contributorId: (json['contributor'] ?? '').toString(),
      ratedById: (json['ratedBy'] ?? '').toString(),
      ratedByName: json['ratedByName'] as String? ?? 'Anonymous Student',
      stars: (json['stars'] as num?)?.toInt() ?? 5,
      review: json['review'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contributor': contributorId,
      'ratedBy': ratedById,
      'ratedByName': ratedByName,
      'stars': stars,
      'review': review,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
