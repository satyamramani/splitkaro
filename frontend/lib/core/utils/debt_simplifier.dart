import '../../features/expenses/models/expense.dart';

class Debt {
  final String debtor;
  final String creditor;
  final double amount;
  final String? group;

  Debt(this.debtor, this.creditor, this.amount, {this.group});

  @override
  String toString() => '$debtor owes $creditor ₹${amount.toStringAsFixed(2)}${group != null && group!.isNotEmpty ? " in $group" : ""}';
}

class DebtSimplifier {
  /// Simplifies a list of debts to minimize the total number of transactions required to settle up.
  static List<Debt> simplifyDebts(List<Debt> initialDebts, {String? group}) {
    // 1. Calculate net balances for each person
    final Map<String, double> balances = {};
    
    for (final debt in initialDebts) {
      balances[debt.debtor] = (balances[debt.debtor] ?? 0) - debt.amount;
      balances[debt.creditor] = (balances[debt.creditor] ?? 0) + debt.amount;
    }

    // 2. Separate into debtors and creditors
    final List<MapEntry<String, double>> debtors = [];
    final List<MapEntry<String, double>> creditors = [];

    balances.forEach((person, balance) {
      if (balance < -0.01) {
        debtors.add(MapEntry(person, -balance));
      } else if (balance > 0.01) {
        creditors.add(MapEntry(person, balance));
      }
    });

    // Sort by largest amounts first to greedily minimize transaction count
    debtors.sort((a, b) => b.value.compareTo(a.value));
    creditors.sort((a, b) => b.value.compareTo(a.value));

    final List<Debt> simplifiedDebts = [];
    
    int i = 0; // debtors index
    int j = 0; // creditors index

    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i].key;
      final creditor = creditors[j].key;
      final debtAmount = debtors[i].value;
      final creditAmount = creditors[j].value;

      final settledAmount = debtAmount < creditAmount ? debtAmount : creditAmount;

      simplifiedDebts.add(Debt(debtor, creditor, settledAmount, group: group));

      debtors[i] = MapEntry(debtor, debtAmount - settledAmount);
      creditors[j] = MapEntry(creditor, creditAmount - settledAmount);

      if (debtors[i].value < 0.01) i++;
      if (creditors[j].value < 0.01) j++;
    }

    return simplifiedDebts;
  }

  /// Returns a map of group name -> amount that [debtor] owes [creditor].
  /// Group name is '' for direct expenses.
  static Map<String, double> getOutstandingGroupDebts({
    required List<Expense> allExpenses,
    required String debtor,
    required String creditor,
  }) {
    final Map<String, double> result = {};

    // Group expenses by group
    final Map<String, List<Expense>> grouped = {};
    for (final exp in allExpenses) {
      grouped.putIfAbsent(exp.group, () => []).add(exp);
    }

    final dNorm = debtor.trim().toLowerCase();
    final cNorm = creditor.trim().toLowerCase();

    for (final entry in grouped.entries) {
      final gName = entry.key;
      final expList = entry.value;

      final List<Debt> rawDebts = [];
      for (final exp in expList) {
        exp.splitOwed.forEach((person, amountOwed) {
          if (person != exp.payer && amountOwed > 0) {
            rawDebts.add(Debt(person, exp.payer, amountOwed, group: gName));
          }
        });
      }

      final simplified = simplifyDebts(rawDebts, group: gName);
      for (final d in simplified) {
        if (d.debtor.trim().toLowerCase() == dNorm &&
            d.creditor.trim().toLowerCase() == cNorm &&
            d.amount > 0.01) {
          result[gName] = (result[gName] ?? 0.0) + d.amount;
        }
      }
    }

    return result;
  }
}
