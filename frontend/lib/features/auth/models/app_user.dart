class AppUser {
  final String id;
  final String name;
  final String email;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] as String? ?? '';
    final rawEmail = json['email'] as String? ?? '';
    final displayName = rawName.isNotEmpty 
        ? rawName 
        : (rawEmail.isNotEmpty ? rawEmail.split('@').first : 'User');

    return AppUser(
      id: json['id'] as String? ?? '',
      name: displayName,
      email: rawEmail,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
