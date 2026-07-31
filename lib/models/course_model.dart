/// course_model.dart — Flutter model for a course within a department.
class CourseModel {
  final String id;
  final String name;
  final String code;
  final String departmentId;
  final String semester;
  final String credit;
  final String status; // 'active' | 'inactive'

  const CourseModel({
    required this.id,
    required this.name,
    required this.code,
    required this.departmentId,
    this.semester = '',
    this.credit = '3',
    this.status = 'active',
  });

  bool get isActive => status == 'active';

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      departmentId: (json['departmentId'] ?? '').toString(),
      semester: json['semester'] as String? ?? '',
      credit: (json['credit'] ?? 3).toString(),
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'departmentId': departmentId,
        'semester': semester,
        'credit': credit,
        'status': status,
      };

  CourseModel copyWith({
    String? id,
    String? name,
    String? code,
    String? departmentId,
    String? semester,
    String? credit,
    String? status,
  }) {
    return CourseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      departmentId: departmentId ?? this.departmentId,
      semester: semester ?? this.semester,
      credit: credit ?? this.credit,
      status: status ?? this.status,
    );
  }

  // Legacy aliases
  factory CourseModel.fromMap(Map<String, dynamic> map) => CourseModel.fromJson(map);
  Map<String, dynamic> toMap() => toJson();
}
