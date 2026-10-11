import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise_clone/core/utils/debt_simplifier.dart';
import 'package:splitwise_clone/features/expenses/models/expense.dart';
import 'package:splitwise_clone/features/expenses/models/expense_category.dart';

void main() {
  group('ExpenseCategory Tests', () {
    test('Correctly suggests Food for dinner/cafe/swiggy', () {
      expect(ExpenseCategory.suggestFromDescription('Dinner at Italian place').id, 'food');
      expect(ExpenseCategory.suggestFromDescription('Zomato order pizza').id, 'food');
      expect(ExpenseCategory.suggestFromDescription('Starbucks coffee').id, 'food');
    });

    test('Correctly suggests Groceries for milk/veggies/blinkit', () {
      expect(ExpenseCategory.suggestFromDescription('Blinkit weekly groceries').id, 'groceries');
      expect(ExpenseCategory.suggestFromDescription('Milk and bread').id, 'groceries');
    });

    test('Correctly suggests Transport for uber/ola/fuel', () {
      expect(ExpenseCategory.suggestFromDescription('Uber to airport').id, 'transport');
      expect(ExpenseCategory.suggestFromDescription('Petrol refill').id, 'transport');
    });

    test('Correctly suggests Travel for flight/hotel/trip', () {
      expect(ExpenseCategory.suggestFromDescription('Flight tickets to Goa').id, 'travel');
      expect(ExpenseCategory.suggestFromDescription('Resort booking').id, 'travel');
    });

    test('Correctly suggests Settlement for settle up keywords', () {
      expect(ExpenseCategory.suggestFromDescription('Settled up via UPI').id, 'settlement');
    });
  });

  group('Settlement Clearing Tests', () {
    test('Settlement exactly clears existing debt to zero', () {
      // 1. Initial expense: Bob owes Alice 50
      final debts = [
        Debt('Bob', 'Alice', 50),
      ];

      // 2. Settlement: Bob pays Alice 50 -> creates Debt('Alice', 'Bob', 50)
      debts.add(Debt('Alice', 'Bob', 50));

      // 3. Simplify
      final simplified = DebtSimplifier.simplifyDebts(debts);

      expect(simplified.isEmpty, true);
    });

    test('Partial settlement reduces debt correctly', () {
      // Bob owes Alice 100, pays 40
      final debts = [
        Debt('Bob', 'Alice', 100),
        Debt('Alice', 'Bob', 40), // Settlement
      ];

      final simplified = DebtSimplifier.simplifyDebts(debts);

      expect(simplified.length, 1);
      expect(simplified.first.debtor, 'Bob');
      expect(simplified.first.creditor, 'Alice');
      expect(simplified.first.amount, 60.0);
    });
  });

  group('Expense Model Tests', () {
    test('Expense parses category and resolves details', () {
      final exp = Expense(
        id: '1',
        description: 'Team Dinner',
        amount: 500,
        payer: 'Alice',
        splitOwed: {'Alice': 250, 'Bob': 250},
        category: 'food',
        date: DateTime.now(),
      );

      expect(exp.categoryDetails.id, 'food');
      expect(exp.categoryDetails.name, 'Food & Dining');
      expect(exp.isSettlement, false);
    });

    test('Settlement Expense is identified correctly', () {
      final exp = Expense(
        id: '2',
        description: 'Settled up via UPI',
        amount: 200,
        payer: 'Bob',
        splitOwed: {'Alice': 200},
        category: 'settlement',
        date: DateTime.now(),
      );

      expect(exp.isSettlement, true);
      expect(exp.categoryDetails.id, 'settlement');
    });
  });

  group('Category Insights & Monthly Aggregation Tests', () {
    test('Aggregates spending per category correctly', () {
      final now = DateTime.now();
      final expenses = [
        Expense(
          id: '1',
          description: 'Lunch',
          amount: 300,
          payer: 'You',
          splitOwed: {'You': 150, 'Bob': 150},
          category: 'food',
          date: now,
        ),
        Expense(
          id: '2',
          description: 'Dinner',
          amount: 500,
          payer: 'Bob',
          splitOwed: {'You': 250, 'Bob': 250},
          category: 'food',
          date: now,
        ),
        Expense(
          id: '3',
          description: 'Uber Ride',
          amount: 200,
          payer: 'You',
          splitOwed: {'You': 100, 'Bob': 100},
          category: 'transport',
          date: now,
        ),
      ];

      final Map<String, double> totals = {};
      final Map<String, double> myShareTotals = {};

      for (var e in expenses) {
        totals[e.category] = (totals[e.category] ?? 0.0) + e.amount;
        myShareTotals[e.category] = (myShareTotals[e.category] ?? 0.0) + (e.splitOwed['You'] ?? 0.0);
      }

      expect(totals['food'], 800.0);
      expect(totals['transport'], 200.0);
      expect(myShareTotals['food'], 400.0);
      expect(myShareTotals['transport'], 100.0);
    });

    test('Filters expenses within the last 3 months', () {
      final now = DateTime.now();
      final currentMonthExpense = Expense(
        id: '1',
        description: 'This month coffee',
        amount: 150,
        payer: 'You',
        splitOwed: {'You': 150},
        category: 'food',
        date: now,
      );
      final twoMonthsAgoExpense = Expense(
        id: '2',
        description: 'Two months ago groceries',
        amount: 800,
        payer: 'You',
        splitOwed: {'You': 800},
        category: 'groceries',
        date: DateTime(now.year, now.month - 2, 15),
      );
      final fiveMonthsAgoExpense = Expense(
        id: '3',
        description: 'Old trip',
        amount: 2500,
        payer: 'You',
        splitOwed: {'You': 2500},
        category: 'travel',
        date: DateTime(now.year, now.month - 5, 10),
      );

      final threeMonthsAgoStart = DateTime(now.year, now.month - 2, 1);
      final all = [currentMonthExpense, twoMonthsAgoExpense, fiveMonthsAgoExpense];
      final in3Months = all.where((e) => e.date.isAfter(threeMonthsAgoStart.subtract(const Duration(seconds: 1)))).toList();

      expect(in3Months.length, 2);
      expect(in3Months.contains(currentMonthExpense), true);
      expect(in3Months.contains(twoMonthsAgoExpense), true);
      expect(in3Months.contains(fiveMonthsAgoExpense), false);
    });
  });
}
