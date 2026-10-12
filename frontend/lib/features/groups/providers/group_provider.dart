import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../auth/providers/user_provider.dart';
import '../models/group.dart';

class GroupState {
  final List<Group> groups;
  final bool isLoading;
  final String? error;

  GroupState({this.groups = const [], this.isLoading = false, this.error});

  GroupState copyWith({List<Group>? groups, bool? isLoading, String? error}) {
    return GroupState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class GroupNotifier extends Notifier<GroupState> {
  PocketBase get pb => ref.read(pocketBaseProvider);

  @override
  GroupState build() {
    _fetchGroups();
    return GroupState(isLoading: true);
  }

  Future<void> _fetchGroups() async {
    try {
      final records = await pb.collection('groups').getFullList(sort: '-created');
      final groups = records.map((r) => Group.fromJson(r.toJson())).toList();
      state = state.copyWith(groups: groups, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await _fetchGroups();
  }

  Future<Group?> createGroup(String name, String description, List<String> members) async {
    try {
      final record = await pb.collection('groups').create(body: {
        'name': name,
        'description': description,
        'members': members,
      });

      final newGroup = Group.fromJson(record.toJson());
      state = state.copyWith(groups: [newGroup, ...state.groups]);
      return newGroup;
    } catch (e) {
      print('Error creating group: $e');
      return null;
    }
  }

  Future<void> deleteGroup(String id) async {
    try {
      await pb.collection('groups').delete(id);
      state = state.copyWith(groups: state.groups.where((g) => g.id != id).toList());
    } catch (e) {
      print('Error deleting group: $e');
    }
  }

  Future<bool> addMemberToGroup(String groupId, String memberName) async {
    final clean = memberName.trim();
    if (clean.isEmpty) return false;

    final groupIndex = state.groups.indexWhere((g) => g.id == groupId);
    if (groupIndex == -1) return false;
    final group = state.groups[groupIndex];

    if (group.members.any((m) => m.trim().toLowerCase() == clean.toLowerCase())) {
      return true; // Already a member
    }

    final updatedMembers = [...group.members, clean];
    try {
      await pb.collection('groups').update(groupId, body: {
        'members': updatedMembers,
      });

      final updatedGroup = Group(
        id: group.id,
        name: group.name,
        description: group.description,
        members: updatedMembers,
        created: group.created,
      );

      state = state.copyWith(
        groups: [
          for (final g in state.groups)
            if (g.id == groupId) updatedGroup else g,
        ],
      );
      return true;
    } catch (e) {
      print('Error adding member to group: $e');
      return false;
    }
  }

  Future<bool> removeMemberFromGroup(String groupId, String memberName) async {
    final clean = memberName.trim().toLowerCase();
    final groupIndex = state.groups.indexWhere((g) => g.id == groupId);
    if (groupIndex == -1) return false;
    final group = state.groups[groupIndex];

    final updatedMembers = group.members.where((m) => m.trim().toLowerCase() != clean).toList();
    try {
      await pb.collection('groups').update(groupId, body: {
        'members': updatedMembers,
      });

      final updatedGroup = Group(
        id: group.id,
        name: group.name,
        description: group.description,
        members: updatedMembers,
        created: group.created,
      );

      state = state.copyWith(
        groups: [
          for (final g in state.groups)
            if (g.id == groupId) updatedGroup else g,
        ],
      );
      return true;
    } catch (e) {
      print('Error removing member from group: $e');
      return false;
    }
  }
}

final groupProvider = NotifierProvider<GroupNotifier, GroupState>(() {
  return GroupNotifier();
});

final userGroupsProvider = Provider<List<Group>>((ref) {
  final groupState = ref.watch(groupProvider);
  final currentUser = ref.watch(currentUserProvider);
  return groupState.groups.where((g) => g.isMember(currentUser)).toList();
});
