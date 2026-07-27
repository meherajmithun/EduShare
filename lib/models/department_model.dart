/// department_model.dart — Flutter model for an academic department.
class DepartmentModel {
  final String id;
  final String name;
  final String code;
  final String description;

  const DepartmentModel({
    required this.id,
    required this.name,
    required this.code,
    this.description = '',
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'description': description,
      };

  // Legacy aliases
  factory DepartmentModel.fromMap(Map<String, dynamic> map) => DepartmentModel.fromJson(map);
  Map<String, dynamic> toMap() => toJson();
}
