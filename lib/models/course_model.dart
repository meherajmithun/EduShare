/// course_model.dart — Flutter model for a course within a department.
class CourseModel {
  final String id;
  final String name;
  final String code;
  final String departmentId;

  const CourseModel({
    required this.id,
    required this.name,
    required this.code,
    required this.departmentId,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      departmentId: (json['departmentId'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'departmentId': departmentId,
      };

  // Legacy aliases
  factory CourseModel.fromMap(Map<String, dynamic> map) => CourseModel.fromJson(map);
  Map<String, dynamic> toMap() => toJson();
}
