import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../../core/services/pocketbase_service.dart';
import '../models/app_user.dart';

import 'auth_provider.dart';

final currentUserProvider = Provider<AppUser>((ref) {
  final authState = ref.watch(authProvider);
  final pb = ref.watch(pocketBaseProvider);

  if (!authState.isAuthenticated || !pb.authStore.isValid) {
    return AppUser(
      id: '',
      name: '',
      email: '',
    );
  }

  final dynamic model = pb.authStore.record ?? pb.authStore.model;
  
  if (model is RecordModel) {
    final rawName = model.getStringValue('name');
    final rawEmail = model.getStringValue('email');
    return AppUser(
      id: model.id,
      name: rawName.isNotEmpty ? rawName : (rawEmail.isNotEmpty ? rawEmail.split('@').first : ''),
      email: rawEmail,
    );
  }

  return AppUser(
    id: '',
    name: '',
    email: '',
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
    final cleanName = name.trim();
    final cleanEmail = email?.trim().toLowerCase();

    // 1. Check if user already exists in current state
    final existingLocal = state.users.where((u) {
      if (cleanEmail != null && cleanEmail.isNotEmpty && u.email.toLowerCase() == cleanEmail) {
        return true;
      }
      return u.name.toLowerCase() == cleanName.toLowerCase();
    }).toList();

    if (existingLocal.isNotEmpty) {
      return existingLocal.first;
    }

    // 2. Query PocketBase to see if user exists by email or name
    try {
      String filter = 'name = "$cleanName"';
      if (cleanEmail != null && cleanEmail.isNotEmpty) {
        filter = 'email = "$cleanEmail" || name = "$cleanName"';
      }
      final searchResult = await pb.collection('users').getList(filter: filter);
      if (searchResult.items.isNotEmpty) {
        final record = searchResult.items.first;
        final rawName = record.getStringValue('name');
        final rawEmail = record.getStringValue('email');
        final existingUser = AppUser(
          id: record.id,
          name: rawName.isNotEmpty ? rawName : (rawEmail.isNotEmpty ? rawEmail.split('@').first : cleanName),
          email: rawEmail,
        );
        state = state.copyWith(users: [...state.users, existingUser]);
        return existingUser;
      }
    } catch (_) {}

    // 3. Otherwise, create a placeholder user in PocketBase
    try {
      final sanitized = cleanName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final userEmail = cleanEmail != null && cleanEmail.isNotEmpty 
          ? cleanEmail 
          : '$sanitized${DateTime.now().millisecondsSinceEpoch % 10000}@example.com';
      
      final record = await pb.collection('users').create(body: {
        'name': cleanName,
        'email': userEmail,
        'password': 'password123',
        'passwordConfirm': 'password123',
      });

      final newUser = AppUser(
        id: record.id,
        name: cleanName,
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
