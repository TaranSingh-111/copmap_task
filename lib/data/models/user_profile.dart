enum UserRole {
  admin,
  officer;

  static UserRole fromDatabaseValue(Object? value) {
    switch (value?.toString().toUpperCase()) {
      case 'ADMIN':
        return UserRole.admin;
      case 'OFFICER':
        return UserRole.officer;
      default:
        throw FormatException('Unsupported profile role: $value');
    }
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.role,
    this.email,
    this.fullName,
    this.createdAt,
  });

  final String id;
  final UserRole role;
  final String? email;
  final String? fullName;
  final DateTime? createdAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final createdAtValue = json['created_at'];
    return UserProfile(
      id: json['id'] as String,
      role: UserRole.fromDatabaseValue(json['role']),
      email: json['email'] as String?,
      fullName: (json['full_name'] ?? json['name']) as String?,
      createdAt: createdAtValue == null
          ? null
          : DateTime.parse(createdAtValue.toString()),
    );
  }
}
