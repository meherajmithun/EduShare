/// department_model.dart — Flutter model for an academic department.
class DepartmentModel {
  final String id;
  final String name;
  final String code;
  final String description;
  final bool isActive;

  const DepartmentModel({
    required this.id,
    required this.name,
    required this.code,
    this.description = '',
    this.isActive = true,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'description': description,
        'isActive': isActive,
      };

  DepartmentModel copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    bool? isActive,
  }) {
    return DepartmentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }

  // Legacy aliases
  factory DepartmentModel.fromMap(Map<String, dynamic> map) => DepartmentModel.fromJson(map);
  Map<String, dynamic> toMap() => toJson();
}
