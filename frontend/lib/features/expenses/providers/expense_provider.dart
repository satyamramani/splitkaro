import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../../groups/providers/group_provider.dart';
import '../../../core/utils/debt_simplifier.dart';
import '../../../core/services/pocketbase_service.dart';

class ExpenseState {
  final List<Expense> expenses;
  final bool isLoading;
  final String? error;

  ExpenseState({this.expenses = const [], this.isLoading = false, this.error});

  ExpenseState copyWith({List<Expense>? expenses, bool? isLoading, String? error}) {
    return ExpenseState(
      expenses: expenses ?? this.expenses,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ExpenseNotifier extends Notifier<ExpenseState> {
  @override
  ExpenseState build() {
    _fetchExpenses(); // Load expenses immediately
    return ExpenseState(isLoading: true);
  }

  Future<void> _fetchExpenses() async {
    try {
      final records = await ref.read(pocketBaseProvider).collection('expenses').getFullList(
        sort: '-created', // Newest first
      );
      
      final expenses = records.map((r) => Expense.fromJson(r.toJson())).toList();
      state = state.copyWith(expenses: expenses, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await _fetchExpenses();
  }

  Future<bool> addExpense(Expense expense) async {
    try {
      final record = await ref.read(pocketBaseProvider).collection('expenses').create(
        body: expense.toJson(),
      );
      
      final newExpense = Expense.fromJson(record.toJson());
      state = state.copyWith(expenses: [newExpense, ...state.expenses]);
      return true;
    } catch (e) {
      print('Error saving expense: $e');
      return false;
    }
  }

  Future<bool> updateExpense(Expense expense) async {
    try {
      final record = await ref.read(pocketBaseProvider).collection('expenses').update(
        expense.id,
        body: expense.toJson(),
      );
      
      final updated = Expense.fromJson(record.toJson());
      state = state.copyWith(
        expenses: state.expenses.map((e) => e.id == expense.id ? updated : e).toList(),
      );
      return true;
    } catch (e) {
      print('Error updating expense: $e');
      return false;
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await ref.read(pocketBaseProvider).collection('expenses').delete(id);
      state = state.copyWith(
        expenses: state.expenses.where((e) => e.id != id).toList(),
      );
    } catch (e) {
      print('Error deleting expense: $e');
    }
  }
}

final expenseProvider = NotifierProvider<ExpenseNotifier, ExpenseState>(() {
  return ExpenseNotifier();
});

final simplifiedDebtsProvider = Provider<List<Debt>>((ref) {
  final expenseState = ref.watch(expenseProvider);
  final groups = ref.watch(groupProvider).groups;
  final List<Debt> allDebts = [];
  
  // 1. Group debts
  for (final g in groups) {
    final gExpenses = expenseState.expenses.where((e) => e.group == g.name).toList();
    final List<Debt> gRawDebts = [];
    for (final exp in gExpenses) {
      exp.splitOwed.forEach((person, amountOwed) {
        if (person != exp.payer && amountOwed > 0) {
          gRawDebts.add(Debt(person, exp.payer, amountOwed, group: g.name));
        }
      });
    }
    allDebts.addAll(DebtSimplifier.simplifyDebts(gRawDebts, group: g.name));
  }

  // 2. Direct debts (no group)
  final directExpenses = expenseState.expenses.where((exp) => exp.group.isEmpty).toList();
  final List<Debt> directRawDebts = [];
  for (final exp in directExpenses) {
    exp.splitOwed.forEach((person, amountOwed) {
      if (person != exp.payer && amountOwed > 0) {
        directRawDebts.add(Debt(person, exp.payer, amountOwed, group: ''));
      }
    });
  }
  allDebts.addAll(DebtSimplifier.simplifyDebts(directRawDebts, group: ''));
  
  return allDebts;
});
