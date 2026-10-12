import '../../auth/models/app_user.dart';

class Group {
  final String id;
  final String name;
  final String description;
  final List<String> members;
  final DateTime created;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.members,
    required this.created,
  });

  bool isMember(AppUser user) {
    if (user.id.isEmpty && user.name.isEmpty) return false;
    return members.any((m) => user.isMe(m));
  }

  factory Group.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'];
    final List<String> parsedMembers = [];
    if (rawMembers is List) {
      for (var m in rawMembers) {
        if (m != null) parsedMembers.add(m.toString());
      }
    }

    return Group(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      members: parsedMembers,
      created: json['created'] != null ? DateTime.parse(json['created']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'members': members,
    };
  }
}
