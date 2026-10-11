import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../../core/services/pocketbase_service.dart';
import '../models/app_user.dart';

final currentUserProvider = Provider<AppUser>((ref) {
  final pb = ref.watch(pocketBaseProvider);
  final dynamic model = pb.authStore.record ?? pb.authStore.model;
  
  if (model is RecordModel) {
    final rawName = model.getStringValue('name');
    final rawEmail = model.getStringValue('email');
    return AppUser(
      id: model.id,
      name: rawName.isNotEmpty ? rawName : (rawEmail.isNotEmpty ? rawEmail.split('@').first : 'Satyam'),
      email: rawEmail,
    );
  }

  // Fallback to Satyam so data is always immediately linked and displayed
  final usersState = ref.watch(usersProvider);
  final satyamUsers = usersState.users.where((u) => u.name.toLowerCase() == 'satyam');
  if (satyamUsers.isNotEmpty) {
    return satyamUsers.first;
  }

  return AppUser(
    id: '13ro5aqn0iy657t',
    name: 'Satyam',
    email: 'satyamramani58554@gmail.com',
  );
});

class UsersState {
  final List<AppUser> users;
  final bool isLoading;
  final String? error;

  UsersState({this.users = const [], this.isLoading = false, this.error});

  UsersState copyWith({List<AppUser>? users, bool? isLoading, String? error}) {
    return UsersState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class UsersNotifier extends Notifier<UsersState> {
  PocketBase get pb => ref.read(pocketBaseProvider);

  @override
  UsersState build() {
    _fetchUsers();
    return UsersState(isLoading: true);
  }

  Future<void> _fetchUsers() async {
    try {
      final records = await pb.collection('users').getFullList(sort: 'name');
      final users = records.map((r) {
        final rawName = r.getStringValue('name');
        final rawEmail = r.getStringValue('email');
        return AppUser(
          id: r.id,
          name: rawName.isNotEmpty ? rawName : (rawEmail.isNotEmpty ? rawEmail.split('@').first : 'User'),
          email: rawEmail,
        );
      }).toList();

      state = state.copyWith(users: users, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await _fetchUsers();
  }

  Future<AppUser?> addUser(String name, [String? email]) async {
    try {
      final sanitized = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final userEmail = email != null && email.isNotEmpty 
          ? email 
          : '$sanitized${DateTime.now().millisecondsSinceEpoch % 10000}@example.com';
      
      final record = await pb.collection('users').create(body: {
        'name': name,
        'email': userEmail,
        'password': 'password123',
        'passwordConfirm': 'password123',
      });

      final newUser = AppUser(
        id: record.id,
        name: name,
        email: userEmail,
      );

      state = state.copyWith(users: [...state.users, newUser]);
      return newUser;
    } catch (e) {
      print('Error adding user: $e');
      return null;
    }
  }
}

final usersProvider = NotifierProvider<UsersNotifier, UsersState>(() {
  return UsersNotifier();
});
