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

  bool isMe(String? identifier) {
    if (identifier == null) return false;
    final clean = identifier.trim().toLowerCase();
    if (clean.isEmpty) return false;

    // Match against current user's name, email, or id
    if (name.isNotEmpty && clean == name.trim().toLowerCase()) return true;
    if (email.isNotEmpty && clean == email.trim().toLowerCase()) return true;
    if (id.isNotEmpty && clean == id.trim().toLowerCase()) return true;

    return false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
