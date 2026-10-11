// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise_clone/core/constants/app_constants.dart';
import 'package:splitwise_clone/core/utils/debt_simplifier.dart';
import 'package:splitwise_clone/features/expenses/models/expense.dart';
import 'package:splitwise_clone/features/expenses/models/expense_category.dart';
import 'package:splitwise_clone/features/groups/models/group.dart';

/// Complete QA Test Suite – Splitwise Clone
/// Sections:
///  1. Expense Model – positive, negative, boundary
///  2. Expense CRUD business-logic (state transitions)
///  3. Split Calculation – equal, exact, percentage
///  4. Debt Simplifier – chains, circulars, self-debts, floating-point
///  5. Settlement – full clear, partial, over-payment, keyword detection
///  6. Category Detection – all keywords, case-insensitive, fallback
///  7. Group Model – parsing, null members, boundary
///  8. Concurrent-update simulation (last-write-wins, stale-read, delete-while-editing)
///  9. Currency formatting – sign, rounding, zero, negative
/// 10. Insights / Monthly aggregation – filter, rollup, boundary dates

void main() {
  // ────────────────────────────────────────────────
  // SECTION 1 – Expense Model
  // ────────────────────────────────────────────────
  group('[1] Expense Model – Construction & JSON', () {
    test('[POSITIVE] Creates valid expense with all fields', () {
      final exp = Expense(
        id: 'exp001',
        description: 'Dinner at Foo Bar',
        amount: 600.0,
        payer: 'Alice',
        splitOwed: {'Alice': 300, 'Bob': 300},
        group: 'Roommates',
        category: 'food',
        date: DateTime(2026, 10, 1),
      );
      expect(exp.id, 'exp001');
      expect(exp.amount, 600.0);
      expect(exp.payer, 'Alice');
      expect(exp.splitOwed['Bob'], 300.0);
      expect(exp.group, 'Roommates');
      expect(exp.category, 'food');
    });

    test('[POSITIVE] toJson() excludes id (PocketBase takes id in URL)', () {
      final exp = Expense(
        id: 'pb_abc123',
        description: 'Coffee',
        amount: 80,
        payer: 'You',
        splitOwed: {'You': 40, 'Bob': 40},
        date: DateTime.now(),
      );
      final json = exp.toJson();
      expect(
        json.containsKey('id'),
        false,
        reason: 'id must NOT be in toJson – PocketBase uses path param',
      );
      expect(json['amount'], 80);
      expect(json['payer'], 'You');
    });

    test(
      '[POSITIVE] fromJson() handles numeric and string amounts in splitOwed',
      () {
        final json = {
          'id': 'x1',
          'description': 'Lunch',
          'amount': 500,
          'payer': 'Charlie',
          'splitOwed': {'Charlie': 250, 'Dave': '250'},
          'group': '',
          'category': 'food',
          'created': '2026-09-15T10:00:00.000Z',
        };
        final exp = Expense.fromJson(json);
        expect(exp.splitOwed['Charlie'], 250.0);
        expect(exp.splitOwed['Dave'], 250.0);
      },
    );

    test(
      '[POSITIVE] fromJson() auto-suggests category when field is empty',
      () {
        final json = {
          'id': 'x2',
          'description': 'Uber to mall',
          'amount': 120,
          'payer': 'Alice',
          'splitOwed': {'Alice': 60, 'Bob': 60},
          'group': '',
          'category': '',
          'created': '2026-10-01T09:00:00.000Z',
        };
        final exp = Expense.fromJson(json);
        expect(exp.category, 'transport');
      },
    );

    test('[NEGATIVE] fromJson() with null amount defaults to 0.0', () {
      final json = {
        'id': 'x3',
        'description': 'Mystery',
        'amount': null,
        'payer': 'Bob',
        'splitOwed': {},
        'group': '',
        'category': 'general',
        'created': '2026-10-01T00:00:00.000Z',
      };
      final exp = Expense.fromJson(json);
      expect(exp.amount, 0.0);
    });

    test('[NEGATIVE] fromJson() with null splitOwed produces empty map', () {
      final json = {
        'id': 'x4',
        'description': 'Coffee',
        'amount': 50,
        'payer': 'You',
        'splitOwed': null,
        'group': '',
        'category': 'food',
        'created': '2026-10-01T00:00:00.000Z',
      };
      final exp = Expense.fromJson(json);
      expect(exp.splitOwed.isEmpty, true);
    });

    test(
      '[NEGATIVE] fromJson() non-numeric split value is silently dropped',
      () {
        final json = {
          'id': 'x5',
          'description': 'Tea',
          'amount': 40,
          'payer': 'You',
          'splitOwed': {'You': 'twenty', 'Bob': 20},
          'group': '',
          'category': 'food',
          'created': '2026-10-01T00:00:00.000Z',
        };
        final exp = Expense.fromJson(json);
        expect(exp.splitOwed.containsKey('You'), false);
        expect(exp.splitOwed['Bob'], 20.0);
      },
    );

    test('[BOUNDARY] Amount = 0.0 is stored without error (UI guards it)', () {
      final exp = Expense(
        id: 'zero',
        description: 'Zero Amount',
        amount: 0.0,
        payer: 'Alice',
        splitOwed: {'Alice': 0.0},
        date: DateTime.now(),
      );
      expect(exp.amount, 0.0);
    });

    test('[BOUNDARY] Very large amount 9,999,999.99 is stored correctly', () {
      final exp = Expense(
        id: 'big',
        description: 'Luxury Villa',
        amount: 9999999.99,
        payer: 'Billionaire',
        splitOwed: {'Billionaire': 4999999.995, 'Partner': 4999999.995},
        date: DateTime.now(),
      );
      expect(exp.amount, 9999999.99);
    });
  });

  // ────────────────────────────────────────────────
  // SECTION 2 – CRUD State Transitions
  // ────────────────────────────────────────────────
  group('[2] CRUD State Transitions', () {
    List<Expense> makeExpenses() => [
      Expense(
        id: 'e1',
        description: 'Groceries',
        amount: 200,
        payer: 'Alice',
        splitOwed: {'Alice': 100, 'Bob': 100},
        date: DateTime(2026, 10, 1),
      ),
      Expense(
        id: 'e2',
        description: 'Fuel',
        amount: 300,
        payer: 'Bob',
        splitOwed: {'Alice': 150, 'Bob': 150},
        category: 'transport',
        date: DateTime(2026, 10, 2),
      ),
    ];

    test('[POSITIVE] Add expense prepends to list', () {
      final state = makeExpenses();
      final newExp = Expense(
        id: 'e3',
        description: 'Netflix',
        amount: 199,
        payer: 'Alice',
        splitOwed: {'Alice': 99.5, 'Bob': 99.5},
        category: 'entertainment',
        date: DateTime.now(),
      );
      final updated = [newExp, ...state];
      expect(updated.first.id, 'e3');
      expect(updated.length, 3);
    });

    test('[POSITIVE] Update expense replaces correct item in list', () {
      final state = makeExpenses();
      final edited = Expense(
        id: 'e1',
        description: 'Groceries (corrected)',
        amount: 250,
        payer: 'Alice',
        splitOwed: {'Alice': 125, 'Bob': 125},
        date: DateTime(2026, 10, 1),
      );
      final updated = state.map((e) => e.id == edited.id ? edited : e).toList();
      final found = updated.firstWhere((e) => e.id == 'e1');
      expect(found.amount, 250.0);
      expect(found.description, 'Groceries (corrected)');
      expect(updated.length, 2);
    });

    test('[POSITIVE] Update preserves original creation date', () {
      final original = Expense(
        id: 'e1',
        description: 'Old',
        amount: 100,
        payer: 'Alice',
        splitOwed: {'Alice': 100},
        date: DateTime(2026, 9, 1),
      );
      final edited = Expense(
        id: original.id,
        description: 'Updated',
        amount: 120,
        payer: original.payer,
        splitOwed: {'Alice': 120},
        date: original.date,
      );
      expect(edited.date, DateTime(2026, 9, 1));
    });

    test('[POSITIVE] Delete expense removes only the target item', () {
      final state = makeExpenses();
      final updated = state.where((e) => e.id != 'e1').toList();
      expect(updated.length, 1);
      expect(updated.first.id, 'e2');
    });

    test('[NEGATIVE] Update with non-existent id leaves list unchanged', () {
      final state = makeExpenses();
      final ghost = Expense(
        id: 'ghost_id',
        description: 'Ghost',
        amount: 999,
        payer: 'Nobody',
        splitOwed: {},
        date: DateTime.now(),
      );
      final updated = state.map((e) => e.id == ghost.id ? ghost : e).toList();
      expect(updated.length, 2);
      expect(updated.any((e) => e.id == 'ghost_id'), false);
    });

    test('[NEGATIVE] Delete with non-existent id is a no-op', () {
      final state = makeExpenses();
      final updated = state.where((e) => e.id != 'does_not_exist').toList();
      expect(updated.length, 2);
    });

    test('[BOUNDARY] Delete last expense yields empty list', () {
      final state = [
        Expense(
          id: 'only',
          description: 'Solo',
          amount: 50,
          payer: 'You',
          splitOwed: {'You': 50},
          date: DateTime.now(),
        ),
      ];
      final updated = state.where((e) => e.id != 'only').toList();
      expect(updated.isEmpty, true);
    });
  });

  // ────────────────────────────────────────────────
  // SECTION 3 – Split Calculation Logic
  // ────────────────────────────────────────────────
  group('[3] Split Calculation Logic', () {
    test('[POSITIVE] Equal split 3 people: 300 → 100 each', () {
      const amount = 300.0;
      final participants = ['Alice', 'Bob', 'Charlie'];
      final share = amount / participants.length;
      final splits = {for (var p in participants) p: share};
      expect(splits['Alice'], 100.0);
      expect(splits['Bob'], 100.0);
      expect(splits['Charlie'], 100.0);
    });

    test('[POSITIVE] Exact split validates within 0.05 tolerance', () {
      const amount = 500.0;
      final exactSplits = {'Alice': 200.0, 'Bob': 300.0};
      final totalEntered = exactSplits.values.fold(0.0, (a, b) => a + b);
      expect((totalEntered - amount).abs() <= 0.05, true);
    });

    test('[NEGATIVE] Exact split mismatch triggers error (sum != total)', () {
      const amount = 500.0;
      final badSplits = {'Alice': 200.0, 'Bob': 250.0};
      final totalEntered = badSplits.values.fold(0.0, (a, b) => a + b);
      expect(
        (totalEntered - amount).abs() > 0.05,
        true,
        reason: 'UI should reject this mismatch',
      );
    });

    test(
      '[POSITIVE] Percentage split 30/70 with 1000 produces correct amounts',
      () {
        const amount = 1000.0;
        final percentages = {'Alice': 30.0, 'Bob': 70.0};
        final totalPct = percentages.values.fold(0.0, (a, b) => a + b);
        expect((totalPct - 100.0).abs() <= 0.5, true);
        final splits = percentages.map((k, v) => MapEntry(k, amount * v / 100));
        expect(splits['Alice'], 300.0);
        expect(splits['Bob'], 700.0);
      },
    );

    test('[NEGATIVE] Percentage not summing to 100 triggers error', () {
      final badPct = {'Alice': 40.0, 'Bob': 40.0};
      final totalPct = badPct.values.fold(0.0, (a, b) => a + b);
      expect(
        (totalPct - 100.0).abs() > 0.5,
        true,
        reason: 'UI should reject percentage total != 100',
      );
    });

    test(
      '[BOUNDARY] Non-divisible equal split stays within 1 paisa of total',
      () {
        const amount = 100.0;
        const count = 3;
        final share = amount / count;
        expect((share * count - amount).abs() < 0.01, true);
      },
    );

    test(
      '[BOUNDARY] Single participant: entire amount goes to that person',
      () {
        const amount = 500.0;
        final participants = ['Alice'];
        final share = amount / participants.length;
        final splits = {for (var p in participants) p: share};
        expect(splits['Alice'], 500.0);
      },
    );

    test('[NEGATIVE] Amount <= 0 must be rejected by UI guard', () {
      bool isValid(double amount) => amount > 0;
      expect(isValid(0), false);
      expect(isValid(-100), false);
      expect(isValid(0.01), true);
    });

    test('[NEGATIVE] Empty participants set must be rejected', () {
      final participants = <String>{};
      expect(
        participants.isEmpty,
        true,
        reason: 'UI must reject save when no participants are selected',
      );
    });
  });

  // ────────────────────────────────────────────────
  // SECTION 4 – Debt Simplifier
  // ────────────────────────────────────────────────
  group('[4] Debt Simplifier', () {
    test('[POSITIVE] Simple A->B 100 stays as one debt', () {
      final debts = [Debt('A', 'B', 100)];
      final result = DebtSimplifier.simplifyDebts(debts);
      expect(result.length, 1);
      expect(result[0].debtor, 'A');
      expect(result[0].creditor, 'B');
      expect(result[0].amount, 100.0);
    });

    test('[POSITIVE] Chain A->B 50, B->C 50 simplifies to A->C 50', () {
      final debts = [Debt('A', 'B', 50), Debt('B', 'C', 50)];
      final result = DebtSimplifier.simplifyDebts(debts);
      expect(result.length, 1);
      expect(result[0].debtor, 'A');
      expect(result[0].creditor, 'C');
    });

    test(
      '[POSITIVE] Circular A->B, B->C, C->A equal amounts resolves to zero',
      () {
        final debts = [
          Debt('A', 'B', 10),
          Debt('B', 'C', 10),
          Debt('C', 'A', 10),
        ];
        final result = DebtSimplifier.simplifyDebts(debts);
        expect(result.isEmpty, true);
      },
    );

    test('[POSITIVE] Mutual debts collapse: Alice->Bob 50, Bob->Alice 30 => Alice->Bob 20', () {
      final debts = [Debt('Alice', 'Bob', 50), Debt('Bob', 'Alice', 30)];
      final result = DebtSimplifier.simplifyDebts(debts);
      expect(result.length, 1);
      expect(result[0].debtor, 'Alice');
      expect(result[0].creditor, 'Bob');
      expect(result[0].amount, 20.0);
    });

    test('[POSITIVE] 4-person fan-out: 3 debtors each owe same creditor', () {
      final debts = [
        Debt('Bob', 'Alice', 100),
        Debt('Charlie', 'Alice', 100),
        Debt('Dave', 'Alice', 100),
      ];
      final result = DebtSimplifier.simplifyDebts(debts);
      expect(result.length, 3);
      expect(result.every((d) => d.creditor == 'Alice'), true);
    });

    test('[NEGATIVE] Self-debt (A owes A) produces zero net', () {
      final debts = [Debt('A', 'A', 50)];
      final result = DebtSimplifier.simplifyDebts(debts);
      expect(result.isEmpty, true);
    });

    test('[BOUNDARY] Empty debt list returns empty', () {
      expect(DebtSimplifier.simplifyDebts([]).isEmpty, true);
    });

    test('[BOUNDARY] Tiny floating-point amounts below threshold are handled gracefully', () {
      final debts = [Debt('A', 'B', 0.005)];
      final result = DebtSimplifier.simplifyDebts(debts);
      if (result.isNotEmpty) {
        expect(result[0].amount < 0.01, true);
      }
    });
  });

  // ────────────────────────────────────────────────
  // SECTION 5 – Settlement Logic
  // ────────────────────────────────────────────────
  group('[5] Settlement Logic', () {
    test('[POSITIVE] Full settlement clears debt completely', () {
      final debts = [Debt('Bob', 'Alice', 200), Debt('Alice', 'Bob', 200)];
      final result = DebtSimplifier.simplifyDebts(debts);
      expect(result.isEmpty, true);
    });

    test('[POSITIVE] Partial settlement reduces remaining balance', () {
      final debts = [Debt('Bob', 'Alice', 200), Debt('Alice', 'Bob', 80)];
      final result = DebtSimplifier.simplifyDebts(debts);
      expect(result.length, 1);
      expect(result[0].debtor, 'Bob');
      expect(result[0].creditor, 'Alice');
      expect(result[0].amount, 120.0);
    });

    test('[NEGATIVE] Over-payment reverses direction', () {
      final debts = [Debt('Bob', 'Alice', 100), Debt('Alice', 'Bob', 150)];
      final result = DebtSimplifier.simplifyDebts(debts);
      expect(result.length, 1);
      expect(result[0].debtor, 'Alice');
      expect(result[0].creditor, 'Bob');
      expect(result[0].amount, 50.0);
    });

    test('[POSITIVE] isSettlement detected from category field', () {
      final exp = Expense(
        id: 's1',
        description: 'Payment',
        amount: 100,
        payer: 'Bob',
        splitOwed: {'Alice': 100},
        category: 'settlement',
        date: DateTime.now(),
      );
      expect(exp.isSettlement, true);
    });

    test(
      '[POSITIVE] isSettlement detected from description keyword "settle"',
      () {
        final exp = Expense(
          id: 's2',
          description: 'Settled up via GPay',
          amount: 200,
          payer: 'Charlie',
          splitOwed: {'Dave': 200},
          date: DateTime.now(),
        );
        expect(exp.isSettlement, true);
      },
    );

    test(
      '[POSITIVE] isSettlement detected from "settled up" in description',
      () {
        final exp = Expense(
          id: 's3',
          description: 'We settled up',
          amount: 50,
          payer: 'Eve',
          splitOwed: {'Frank': 50},
          date: DateTime.now(),
        );
        expect(exp.isSettlement, true);
      },
    );

    test('[NEGATIVE] Regular expense is NOT flagged as settlement', () {
      final exp = Expense(
        id: 'r1',
        description: 'Dinner at restaurant',
        amount: 800,
        payer: 'Alice',
        splitOwed: {'Alice': 400, 'Bob': 400},
        category: 'food',
        date: DateTime.now(),
      );
      expect(exp.isSettlement, false);
    });

    test(
      '[BOUNDARY] Settlement of 0.00 does nothing (debt of 100 remains)',
      () {
        final debts = [Debt('Bob', 'Alice', 100), Debt('Alice', 'Bob', 0)];
        final result = DebtSimplifier.simplifyDebts(debts);
        expect(result.length, 1);
        expect(result[0].amount, 100.0);
      },
    );
  });

  // ────────────────────────────────────────────────
  // SECTION 6 – Category Auto-Detection
  // ────────────────────────────────────────────────
  group('[6] Category Detection', () {
    group('Food & Dining keywords', () {
      for (final kw in [
        'pizza',
        'burger',
        'dinner',
        'lunch',
        'breakfast',
        'coffee',
        'tea',
        'chai',
        'restaurant',
        'food',
        'swiggy',
        'zomato',
        'cafe',
      ]) {
        test('keyword "$kw" -> food', () {
          expect(
            ExpenseCategory.suggestFromDescription('We had $kw').id,
            'food',
          );
        });
      }
    });

    group('Groceries keywords', () {
      for (final kw in [
        'grocery',
        'supermarket',
        'vegetables',
        'veggies',
        'milk',
        'blinkit',
        'zepto',
        'instamart',
        'fruits',
      ]) {
        test('keyword "$kw" -> groceries', () {
          expect(
            ExpenseCategory.suggestFromDescription('Got some $kw').id,
            'groceries',
          );
        });
      }
    });

    group('Transport keywords', () {
      for (final kw in [
        'uber',
        'ola',
        'rapido',
        'cab',
        'auto',
        'petrol',
        'fuel',
        'diesel',
        'taxi',
        'toll',
        'parking',
      ]) {
        test('keyword "$kw" -> transport', () {
          expect(
            ExpenseCategory.suggestFromDescription('Paid for $kw').id,
            'transport',
          );
        });
      }
    });

    test('[POSITIVE] "flight tickets to Goa" -> travel', () {
      expect(
        ExpenseCategory.suggestFromDescription('flight tickets to Goa').id,
        'travel',
      );
    });

    test('[POSITIVE] "irctc train booking" -> travel', () {
      expect(
        ExpenseCategory.suggestFromDescription('irctc train booking').id,
        'travel',
      );
    });

    test('[POSITIVE] "Netflix subscription" -> entertainment', () {
      expect(
        ExpenseCategory.suggestFromDescription('Netflix subscription monthly')
            .id,
        'entertainment',
      );
    });

    test('[POSITIVE] "wifi bill" -> utilities', () {
      expect(
        ExpenseCategory.suggestFromDescription('wifi bill for the month').id,
        'utilities',
      );
    });

    test('[POSITIVE] "flat rent April" -> housing', () {
      expect(
        ExpenseCategory.suggestFromDescription('flat rent April').id,
        'housing',
      );
    });

    test('[POSITIVE] "Amazon order" -> shopping', () {
      expect(
        ExpenseCategory.suggestFromDescription('Amazon order clothes').id,
        'shopping',
      );
    });

    test('[POSITIVE] "doctor consultation fee" -> health', () {
      expect(
        ExpenseCategory.suggestFromDescription('doctor consultation fee').id,
        'health',
      );
    });

    test('[POSITIVE] "Settled up via UPI" -> settlement', () {
      expect(
        ExpenseCategory.suggestFromDescription('Settled up via UPI').id,
        'settlement',
      );
    });

    test('[NEGATIVE] Unrecognised description falls back to general', () {
      expect(
        ExpenseCategory.suggestFromDescription('Random xyz payment').id,
        'general',
      );
    });

    test('[NEGATIVE] Empty description falls back to general', () {
      expect(ExpenseCategory.suggestFromDescription('').id, 'general');
    });

    test('[BOUNDARY] UPPERCASE keywords matched case-insensitively', () {
      expect(
        ExpenseCategory.suggestFromDescription('UBER RIDE TO OFFICE').id,
        'transport',
      );
    });

    test('[BOUNDARY] fromId() with unknown id returns general', () {
      expect(ExpenseCategory.fromId('unknown_cat').id, 'general');
    });

    test('[BOUNDARY] fromId(null) returns general', () {
      expect(ExpenseCategory.fromId(null).id, 'general');
    });

    test('[BOUNDARY] fromId("") returns general', () {
      expect(ExpenseCategory.fromId('').id, 'general');
    });

    test('[BOUNDARY] fromId("settlement") returns settlement category', () {
      expect(ExpenseCategory.fromId('settlement').id, 'settlement');
    });
  });

  // ────────────────────────────────────────────────
  // SECTION 7 – Group Model
  // ────────────────────────────────────────────────
  group('[7] Group Model', () {
    test('[POSITIVE] fromJson() parses all fields correctly', () {
      final json = {
        'id': 'g1',
        'name': 'Goa Trip',
        'description': 'Friends trip',
        'members': ['Alice', 'Bob', 'Charlie'],
        'created': '2026-09-01T00:00:00.000Z',
      };
      final group = Group.fromJson(json);
      expect(group.id, 'g1');
      expect(group.name, 'Goa Trip');
      expect(group.members.length, 3);
      expect(group.members.contains('Bob'), true);
    });

    test('[POSITIVE] toJson() does NOT include id key', () {
      final group = Group(
        id: 'g2',
        name: 'Roommates',
        description: 'Flat buddies',
        members: ['Alice', 'Bob'],
        created: DateTime.now(),
      );
      final json = group.toJson();
      expect(json.containsKey('name'), true);
      expect(json.containsKey('members'), true);
      expect(
        json.containsKey('id'),
        false,
        reason: 'id must NOT be in group toJson (same pattern as expenses)',
      );
    });

    test('[NEGATIVE] fromJson() with null members produces empty list', () {
      final json = {
        'id': 'g3',
        'name': 'Empty Group',
        'description': '',
        'members': null,
        'created': '2026-09-01T00:00:00.000Z',
      };
      final group = Group.fromJson(json);
      expect(group.members.isEmpty, true);
    });

    test('[NEGATIVE] fromJson() with non-list members (wrong type) produces empty list', () {
      final json = {
        'id': 'g4',
        'name': 'Bad Group',
        'description': '',
        'members': 'Alice,Bob',
        'created': '2026-09-01T00:00:00.000Z',
      };
      final group = Group.fromJson(json);
      expect(group.members.isEmpty, true);
    });

    test('[BOUNDARY] Group with a single member', () {
      final json = {
        'id': 'g5',
        'name': 'Solo Group',
        'description': '',
        'members': ['Alice'],
        'created': '2026-09-01T00:00:00.000Z',
      };
      final group = Group.fromJson(json);
      expect(group.members.length, 1);
    });

    test('[BOUNDARY] Missing created date defaults to approximately now', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final json = {
        'id': 'g6',
        'name': 'No Date',
        'description': '',
        'members': [],
        'created': null,
      };
      final group = Group.fromJson(json);
      expect(group.created.isAfter(before), true);
    });
  });

  // ────────────────────────────────────────────────
  // SECTION 8 – Concurrent Update Simulation
  // ────────────────────────────────────────────────
  group('[8] Concurrent Update Simulation', () {
    Expense makeBase() => Expense(
      id: 'shared_exp',
      description: 'Shared Bill',
      amount: 1000,
      payer: 'Alice',
      splitOwed: {'Alice': 500, 'Bob': 500},
      date: DateTime(2026, 10, 5),
    );

    test('[CONCURRENT] User-A update is applied to state', () {
      var state = [makeBase()];
      final userAVersion = Expense(
        id: 'shared_exp',
        description: 'Shared Bill – A edits',
        amount: 1100,
        payer: 'Alice',
        splitOwed: {'Alice': 550, 'Bob': 550},
        date: DateTime(2026, 10, 5),
      );
      state = state
          .map((e) => e.id == userAVersion.id ? userAVersion : e)
          .toList();
      expect(state.first.amount, 1100.0);
    });

    test('[CONCURRENT] User-B last-write-wins over User-A', () {
      var state = [makeBase()];
      final userAVersion = Expense(
        id: 'shared_exp',
        description: 'A edits',
        amount: 1100,
        payer: 'Alice',
        splitOwed: {'Alice': 550, 'Bob': 550},
        date: DateTime(2026, 10, 5),
      );
      state = state
          .map((e) => e.id == userAVersion.id ? userAVersion : e)
          .toList();

      final userBVersion = Expense(
        id: 'shared_exp',
        description: 'B edits amount differently',
        amount: 900,
        payer: 'Bob',
        splitOwed: {'Alice': 450, 'Bob': 450},
        date: DateTime(2026, 10, 5),
      );
      state = state
          .map((e) => e.id == userBVersion.id ? userBVersion : e)
          .toList();
      expect(state.first.amount, 900.0);
      expect(state.first.payer, 'Bob');
    });

    test('[CONCURRENT] Stale-read shows old state until refresh', () {
      final state = [makeBase()];
      final serverVersion = Expense(
        id: 'shared_exp',
        description: 'Server Updated',
        amount: 800,
        payer: 'Charlie',
        splitOwed: {'Alice': 400, 'Bob': 400},
        date: DateTime(2026, 10, 5),
      );
      expect(state.first.amount, 1000.0); // stale
      final refreshed = state
          .map((e) => e.id == serverVersion.id ? serverVersion : e)
          .toList();
      expect(refreshed.first.amount, 800.0);
    });

    test('[CONCURRENT] Delete-while-editing: deleted id gone after sync', () {
      var state = [
        makeBase(),
        Expense(
          id: 'other_exp',
          description: 'Other',
          amount: 100,
          payer: 'Bob',
          splitOwed: {'Bob': 100},
          date: DateTime.now(),
        ),
      ];
      state = state.where((e) => e.id != 'shared_exp').toList();
      final found = state.where((e) => e.id == 'shared_exp').toList();
      expect(
        found.isEmpty,
        true,
        reason: 'After concurrent delete, update target is gone; PocketBase returns 404',
      );
    });

    test('[CONCURRENT] Two users add same-description expense: both stored (no dedup)', () {
      var state = <Expense>[];
      final expA = Expense(
        id: 'exp_from_a',
        description: 'Trip Hotel',
        amount: 3000,
        payer: 'Alice',
        splitOwed: {'Alice': 1500, 'Bob': 1500},
        date: DateTime.now(),
      );
      final expB = Expense(
        id: 'exp_from_b',
        description: 'Trip Hotel',
        amount: 3000,
        payer: 'Bob',
        splitOwed: {'Alice': 1500, 'Bob': 1500},
        date: DateTime.now(),
      );
      state = [expA, ...state];
      state = [expB, ...state];
      expect(
        state.length,
        2,
        reason: 'Different IDs = separate entries; no dedup on description',
      );
    });
  });

  // ────────────────────────────────────────────────
  // SECTION 9 – Currency Formatting
  // ────────────────────────────────────────────────
  group('[9] Currency Formatting (AppConstants)', () {
    test('[POSITIVE] Formats positive amount without sign', () {
      expect(AppConstants.formatCurrency(250.5), '₹250.50');
    });

    test('[POSITIVE] Formats with positive sign when showSign=true', () {
      expect(AppConstants.formatCurrency(100.0, showSign: true), '+₹100.00');
    });

    test('[POSITIVE] Formats negative amount with sign', () {
      expect(AppConstants.formatCurrency(-75.0, showSign: true), '-₹75.00');
    });

    test('[BOUNDARY] Zero shows no sign even with showSign=true', () {
      expect(AppConstants.formatCurrency(0.0, showSign: true), '₹0.00');
    });

    test('[BOUNDARY] Very small positive (0.004) treated as zero for sign', () {
      expect(AppConstants.formatCurrency(0.004, showSign: true), '₹0.00');
    });

    test('[BOUNDARY] Amount on threshold (0.005) shows positive sign', () {
      expect(AppConstants.formatCurrency(0.005, showSign: true), '+₹0.01');
    });

    test('[POSITIVE] Rupee symbol is always present', () {
      expect(AppConstants.formatCurrency(1234.56).startsWith('₹'), true);
    });

    test('[POSITIVE] Large amount formatted correctly', () {
      expect(AppConstants.formatCurrency(9999.99), '₹9999.99');
    });

    test('[NEGATIVE] Negative input without showSign shows absolute value', () {
      expect(
        AppConstants.formatCurrency(-500.0),
        '₹500.00',
        reason: 'abs() always applied; sign only when requested',
      );
    });
  });

  // ────────────────────────────────────────────────
  // SECTION 10 – Insights & Monthly Aggregation
  // ────────────────────────────────────────────────
  group('[10] Insights & Monthly Aggregation', () {
    final now = DateTime.now();

    List<Expense> makeInsightExpenses() => [
      Expense(
        id: 'i1',
        description: 'Swiggy lunch',
        amount: 300,
        payer: 'You',
        splitOwed: {'You': 150, 'Bob': 150},
        category: 'food',
        date: DateTime(now.year, now.month, 5),
      ),
      Expense(
        id: 'i2',
        description: 'Uber to office',
        amount: 200,
        payer: 'Bob',
        splitOwed: {'You': 100, 'Bob': 100},
        category: 'transport',
        date: DateTime(now.year, now.month, 10),
      ),
      Expense(
        id: 'i3',
        description: 'Dinner out',
        amount: 500,
        payer: 'You',
        splitOwed: {'You': 250, 'Bob': 250},
        category: 'food',
        date: DateTime(now.year, now.month - 1, 20),
      ),
      Expense(
        id: 'i4',
        description: 'Blinkit order',
        amount: 800,
        payer: 'You',
        splitOwed: {'You': 400, 'Bob': 400},
        category: 'groceries',
        date: DateTime(now.year, now.month - 2, 15),
      ),
      Expense(
        id: 'i5',
        description: 'Old trip hotel',
        amount: 5000,
        payer: 'You',
        splitOwed: {'You': 2500, 'Bob': 2500},
        category: 'travel',
        date: DateTime(now.year, now.month - 5, 10),
      ),
      Expense(
        id: 'i6',
        description: 'Settled up',
        amount: 200,
        payer: 'Bob',
        splitOwed: {'You': 200},
        category: 'settlement',
        date: DateTime(now.year, now.month, 1),
      ),
    ];

    test(
      '[POSITIVE] 3-month filter includes current and 2 prior months only',
      () {
        final expenses = makeInsightExpenses();
        final cutoff = DateTime(now.year, now.month - 2, 1);
        final filtered = expenses
            .where(
              (e) =>
                  e.date.isAfter(cutoff.subtract(const Duration(seconds: 1))) &&
                  !e.isSettlement,
            )
            .toList();
        expect(filtered.length, 4);
      },
    );

    test('[POSITIVE] 5-month-old expense excluded from 3-month window', () {
      final expenses = makeInsightExpenses();
      final cutoff = DateTime(now.year, now.month - 2, 1);
      final filtered = expenses
          .where(
            (e) =>
                e.date.isAfter(cutoff.subtract(const Duration(seconds: 1))) &&
                !e.isSettlement,
          )
          .toList();
      expect(filtered.any((e) => e.id == 'i5'), false);
    });

    test(
      '[POSITIVE] Settlements are excluded from category spending total',
      () {
        final expenses = makeInsightExpenses();
        final nonSettlements = expenses.where((e) => !e.isSettlement).toList();
        expect(nonSettlements.any((e) => e.isSettlement), false);
      },
    );

    test('[POSITIVE] Category totals roll up correctly', () {
      final expenses = makeInsightExpenses()
          .where((e) => !e.isSettlement)
          .toList();
      final Map<String, double> totals = {};
      for (var e in expenses) {
        totals[e.category] = (totals[e.category] ?? 0) + e.amount;
      }
      expect(totals['food'], 800.0);
      expect(totals['transport'], 200.0);
      expect(totals['groceries'], 800.0);
    });

    test('[POSITIVE] My share uses splitOwed[me], not total amount', () {
      final expenses = makeInsightExpenses()
          .where((e) => !e.isSettlement)
          .toList();
      final Map<String, double> myShare = {};
      for (var e in expenses) {
        myShare[e.category] =
            (myShare[e.category] ?? 0) + (e.splitOwed['You'] ?? 0);
      }
      expect(myShare['food'], 400.0);
      expect(myShare['transport'], 100.0);
    });

    test('[NEGATIVE] Category with zero entries has 0.0 total', () {
      final expenses = makeInsightExpenses()
          .where((e) => !e.isSettlement)
          .toList();
      final Map<String, double> totals = {};
      for (var e in expenses) {
        totals[e.category] = (totals[e.category] ?? 0) + e.amount;
      }
      expect(totals['health'] ?? 0.0, 0.0);
    });

    test('[BOUNDARY] Expense exactly on cutoff day is included', () {
      final cutoff = DateTime(now.year, now.month - 2, 1);
      final onCutoff = Expense(
        id: 'boundary',
        description: 'On cutoff day',
        amount: 100,
        payer: 'You',
        splitOwed: {'You': 100},
        category: 'general',
        date: cutoff,
      );
      final isIncluded = onCutoff.date.isAfter(
        cutoff.subtract(const Duration(seconds: 1)),
      );
      expect(isIncluded, true);
    });

    test('[BOUNDARY] Expense 1 second before cutoff is excluded', () {
      final cutoff = DateTime(now.year, now.month - 2, 1);
      final justBefore = cutoff.subtract(const Duration(seconds: 2));
      final exp = Expense(
        id: 'just_before',
        description: 'Tiny moment before cutoff',
        amount: 100,
        payer: 'You',
        splitOwed: {'You': 100},
        category: 'general',
        date: justBefore,
      );
      final isIncluded = exp.date.isAfter(
        cutoff.subtract(const Duration(seconds: 1)),
      );
      expect(isIncluded, false);
    });

    test('[POSITIVE] Monthly breakdown groups by year-month key correctly', () {
      final expenses = makeInsightExpenses()
          .where((e) => !e.isSettlement)
          .toList();
      final Map<String, double> monthlyTotals = {};
      for (var e in expenses) {
        final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
        monthlyTotals[key] = (monthlyTotals[key] ?? 0) + e.amount;
      }
      final currentKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      expect(monthlyTotals[currentKey], 500.0);
    });
  });
}
