class Department {
  const Department({
    required this.id,
    required this.name,
    required this.active,
    required this.iconKey,
  });

  final String id;
  final String name;
  final bool active;
  final String iconKey;

  factory Department.fromMap(String id, Map<String, dynamic> data) {
    final rawName = data['name'] ?? data['departmentName'];
    final rawIcon = data['iconKey'] ?? data['icon'];
    final rawActive = data['active'] ?? data['isActive'];
    return Department(
      id: id,
      name: rawName is String && rawName.trim().isNotEmpty
          ? rawName.trim()
          : 'Department',
      // Older department docs may not have an active flag. Treat those as
      // visible; only an explicit false value hides a department.
      active: rawActive is bool ? rawActive : true,
      iconKey: rawIcon is String && rawIcon.trim().isNotEmpty
          ? rawIcon.trim()
          : 'domain',
    );
  }
}
