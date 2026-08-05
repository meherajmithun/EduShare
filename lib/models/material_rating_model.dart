/// material_rating_model.dart — Flutter model for a per-material student rating.
class MaterialRatingModel {
  final String id;
  final String materialId;
  final String contributorId;
  final String ratedBy;
  final String ratedByName;
  final int stars;
  final String review;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MaterialRatingModel({
    required this.id,
    required this.materialId,
    required this.contributorId,
    required this.ratedBy,
    required this.ratedByName,
    required this.stars,
    this.review = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory MaterialRatingModel.fromJson(Map<String, dynamic> json) {
    return MaterialRatingModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      materialId: (json['materialId'] ?? '').toString(),
      contributorId: (json['contributorId'] ?? '').toString(),
      ratedBy: (json['ratedBy'] ?? '').toString(),
      ratedByName: json['ratedByName'] as String? ?? '',
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      review: json['review'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'materialId': materialId,
        'contributorId': contributorId,
        'ratedBy': ratedBy,
        'ratedByName': ratedByName,
        'stars': stars,
        'review': review,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
