enum UserRole { student, receptionist, admin }

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.departmentId,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? departmentId;

  factory AppUser.fromMap(String id, Map<String, dynamic> data) {
    final rawRole = data['role']?.toString().trim().toLowerCase();
    UserRole? role;
    for (final candidate in UserRole.values) {
      if (candidate.name == rawRole) role = candidate;
    }
    if (role == null) {
      throw const FormatException(
          'This account has no valid app role. Contact an administrator.');
    }

    return AppUser(
      id: id,
      name: data['name'] as String? ?? 'UniQueue user',
      email: data['email'] as String? ?? '',
      role: role,
      departmentId: data['departmentId'] as String?,
    );
  }
}
