import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/presentation/main_layout.dart';
import '../../features/expenses/models/expense.dart';
import '../../features/expenses/presentation/add_expense_screen.dart';

import '../../features/groups/models/group.dart';
import '../../features/groups/presentation/group_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: authState.isAuthenticated ? '/dashboard' : '/login',
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

      if (!isAuth && !isLoginRoute) {
        return '/login';
      }
      
      if (isAuth && isLoginRoute) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const MainLayout(),
      ),
      GoRoute(
        path: '/add-expense',
        builder: (context, state) {
          if (state.extra is Expense) {
            return AddExpenseScreen(existingExpense: state.extra as Expense);
          }
          final groupName = state.extra as String?;
          return AddExpenseScreen(initialGroupName: groupName);
        },
      ),
      GoRoute(
        path: '/edit-expense',
        builder: (context, state) {
          final expense = state.extra as Expense?;
          return AddExpenseScreen(existingExpense: expense);
        },
      ),
      GoRoute(
        path: '/group-detail/:groupId',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId'] ?? '';
          final group = state.extra as Group?;
          return GroupDetailScreen(groupId: groupId, initialGroup: group);
        },
      ),
    ],
  );
});
