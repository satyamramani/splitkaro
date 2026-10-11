import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise_clone/core/utils/debt_simplifier.dart';

void main() {
  test('Simplifies chain of debts: A->B 10, B->C 10 should become A->C 10', () {
    final initial = [
      Debt('A', 'B', 10),
      Debt('B', 'C', 10),
    ];
    
    final simplified = DebtSimplifier.simplifyDebts(initial);
    
    expect(simplified.length, 1);
    expect(simplified[0].debtor, 'A');
    expect(simplified[0].creditor, 'C');
    expect(simplified[0].amount, 10.0);
  });

  test('Simplifies circular debts: A->B 10, B->C 10, C->A 10 should become 0 transactions', () {
    final initial = [
      Debt('A', 'B', 10),
      Debt('B', 'C', 10),
      Debt('C', 'A', 10),
    ];
    
    final simplified = DebtSimplifier.simplifyDebts(initial);
    
    expect(simplified.isEmpty, true);
  });

  test('Handles uneven splits', () {
    final initial = [
      Debt('Alice', 'Bob', 50),
      Debt('Charlie', 'Bob', 25),
      Debt('Bob', 'David', 75),
    ];
    
    // Bob receives 75, owes 75 -> Net 0.
    // Alice owes 50, Charlie owes 25, David is owed 75.
    // Simplified: Alice owes David 50, Charlie owes David 25.
    
    final simplified = DebtSimplifier.simplifyDebts(initial);
    
    expect(simplified.length, 2);
    
    final aliceDebt = simplified.firstWhere((d) => d.debtor == 'Alice');
    expect(aliceDebt.creditor, 'David');
    expect(aliceDebt.amount, 50.0);

    final charlieDebt = simplified.firstWhere((d) => d.debtor == 'Charlie');
    expect(charlieDebt.creditor, 'David');
    expect(charlieDebt.amount, 25.0);
  });
}
