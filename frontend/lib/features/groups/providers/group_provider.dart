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
}

final groupProvider = NotifierProvider<GroupNotifier, GroupState>(() {
  return GroupNotifier();
});

final userGroupsProvider = Provider<List<Group>>((ref) {
  final groupState = ref.watch(groupProvider);
  final currentUser = ref.watch(currentUserProvider);
  return groupState.groups.where((g) => g.isMember(currentUser)).toList();
});
