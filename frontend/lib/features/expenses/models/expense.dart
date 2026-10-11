import 'expense_category.dart';

class Expense {
  final String id;
  final String description;
  final double amount;
  final String payer;
  final Map<String, double> splitOwed; 
  final String group;
  final String category;
  final DateTime date;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.payer,
    required this.splitOwed,
    this.group = '',
    this.category = 'general',
    required this.date,
  });

  bool get isSettlement => 
      category == 'settlement' ||
      description.toLowerCase().startsWith('settle') || 
      description.toLowerCase().contains('settled up');

  ExpenseCategory get categoryDetails {
    if (isSettlement) return ExpenseCategory.settlement;
    if (category.isNotEmpty && category != 'general') {
      return ExpenseCategory.fromId(category);
    }
    return ExpenseCategory.suggestFromDescription(description);
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    final rawSplit = json['splitOwed'];
    final parsedSplit = <String, double>{};
    
    if (rawSplit is Map) {
      rawSplit.forEach((key, value) {
        if (value is num) {
          parsedSplit[key.toString()] = value.toDouble();
        } else if (value != null) {
          final parsed = double.tryParse(value.toString());
          if (parsed != null) parsedSplit[key.toString()] = parsed;
        }
      });
    }

    final desc = json['description'] as String? ?? '';
    final rawCat = json['category'] as String? ?? '';
    final assignedCategory = rawCat.isNotEmpty 
        ? rawCat 
        : ExpenseCategory.suggestFromDescription(desc).id;

    return Expense(
      id: json['id'] as String? ?? '',
      description: desc,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      payer: json['payer'] as String? ?? '',
      splitOwed: parsedSplit,
      group: json['group'] as String? ?? '',
      category: assignedCategory,
      date: json['created'] != null ? DateTime.parse(json['created']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'amount': amount,
      'payer': payer,
      'splitOwed': splitOwed,
      'group': group,
      'category': category,
    };
  }
}
