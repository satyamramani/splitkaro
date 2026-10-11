import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../../core/services/pocketbase_service.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  PocketBase get pb => ref.read(pocketBaseProvider);

  @override
  AuthState build() {
    final pocketBase = ref.watch(pocketBaseProvider);
    pocketBase.authStore.onChange.listen((e) {
      state = state.copyWith(isAuthenticated: pocketBase.authStore.isValid);
    });
    return AuthState(isAuthenticated: pocketBase.authStore.isValid);
  }

  String _formatError(dynamic e) {
    if (e is ClientException) {
      final response = e.response;
      if (response is Map<String, dynamic>) {
        final data = response['data'];
        if (data is Map<String, dynamic> && data.isNotEmpty) {
          final firstKey = data.keys.first;
          final firstError = data[firstKey]['message'];
          return '$firstKey: $firstError';
        }
        return response['message']?.toString() ?? e.toString();
      }
    }
    return e.toString();
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await pb.collection('users').authWithPassword(email, password);
      state = state.copyWith(isLoading: false, isAuthenticated: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _formatError(e));
    }
  }

  Future<void> signup(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await pb.collection('users').create(body: {
        'name': name,
        'email': email,
        'password': password,
        'passwordConfirm': password,
      });
      // After signup, log them in
      await login(email, password);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _formatError(e));
    }
  }

  void logout() {
    pb.authStore.clear();
    state = state.copyWith(isAuthenticated: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
