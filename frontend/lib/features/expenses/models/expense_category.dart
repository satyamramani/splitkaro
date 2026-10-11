import 'package:flutter/material.dart';

class ExpenseCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  static const ExpenseCategory food = ExpenseCategory(
    id: 'food',
    name: 'Food & Dining',
    icon: Icons.restaurant,
    color: Color(0xFFF59E0B), // Amber
  );

  static const ExpenseCategory groceries = ExpenseCategory(
    id: 'groceries',
    name: 'Groceries',
    icon: Icons.shopping_cart,
    color: Color(0xFF10B981), // Emerald
  );

  static const ExpenseCategory transport = ExpenseCategory(
    id: 'transport',
    name: 'Transport',
    icon: Icons.directions_car,
    color: Color(0xFF3B82F6), // Blue
  );

  static const ExpenseCategory entertainment = ExpenseCategory(
    id: 'entertainment',
    name: 'Entertainment',
    icon: Icons.movie_outlined,
    color: Color(0xFFEC4899), // Pink
  );

  static const ExpenseCategory utilities = ExpenseCategory(
    id: 'utilities',
    name: 'Bills & Utilities',
    icon: Icons.bolt,
    color: Color(0xFFEAB308), // Yellow
  );

  static const ExpenseCategory housing = ExpenseCategory(
    id: 'housing',
    name: 'Rent & Housing',
    icon: Icons.home_outlined,
    color: Color(0xFF8B5CF6), // Purple
  );

  static const ExpenseCategory travel = ExpenseCategory(
    id: 'travel',
    name: 'Travel & Trips',
    icon: Icons.flight,
    color: Color(0xFF06B6D4), // Cyan
  );

  static const ExpenseCategory shopping = ExpenseCategory(
    id: 'shopping',
    name: 'Shopping',
    icon: Icons.shopping_bag_outlined,
    color: Color(0xFFF97316), // Orange
  );

  static const ExpenseCategory health = ExpenseCategory(
    id: 'health',
    name: 'Health & Medical',
    icon: Icons.medical_services_outlined,
    color: Color(0xFFEF4444), // Red
  );

  static const ExpenseCategory settlement = ExpenseCategory(
    id: 'settlement',
    name: 'Settlement',
    icon: Icons.handshake_outlined,
    color: Color(0xFF14B8A6), // Teal
  );

  static const ExpenseCategory general = ExpenseCategory(
    id: 'general',
    name: 'General',
    icon: Icons.receipt_long,
    color: Color(0xFF6366F1), // Indigo
  );

  static const List<ExpenseCategory> allCategories = [
    food,
    groceries,
    transport,
    entertainment,
    utilities,
    housing,
    travel,
    shopping,
    health,
    general,
  ];

  static ExpenseCategory fromId(String? id) {
    if (id == null || id.isEmpty) return general;
    return allCategories.firstWhere(
      (c) => c.id == id.toLowerCase(),
      orElse: () => id == 'settlement' ? settlement : general,
    );
  }

  /// Automatically suggests a category based on the description text
  static ExpenseCategory suggestFromDescription(String desc) {
    final lower = desc.toLowerCase();
    if (lower.startsWith('settle') || lower.contains('settled up')) {
      return settlement;
    }
    if (lower.contains('pizza') ||
        lower.contains('burger') ||
        lower.contains('dinner') ||
        lower.contains('lunch') ||
        lower.contains('breakfast') ||
        lower.contains('coffee') ||
        lower.contains('tea') ||
        lower.contains('chai') ||
        lower.contains('restaurant') ||
        lower.contains('food') ||
        lower.contains('swiggy') ||
        lower.contains('zomato') ||
        lower.contains('cafe')) {
      return food;
    }
    if (lower.contains('grocery') ||
        lower.contains('supermarket') ||
        lower.contains('vegetables') ||
        lower.contains('veggies') ||
        lower.contains('milk') ||
        lower.contains('blinkit') ||
        lower.contains('zepto') ||
        lower.contains('instamart') ||
        lower.contains('fruits')) {
      return groceries;
    }
    if (lower.contains('uber') ||
        lower.contains('ola') ||
        lower.contains('rapido') ||
        lower.contains('cab') ||
        lower.contains('auto') ||
        lower.contains('petrol') ||
        lower.contains('fuel') ||
        lower.contains('diesel') ||
        lower.contains('taxi') ||
        lower.contains('toll') ||
        lower.contains('parking')) {
      return transport;
    }
    if (lower.contains('flight') ||
        lower.contains('hotel') ||
        lower.contains('resort') ||
        lower.contains('trip') ||
        lower.contains('vacation') ||
        lower.contains('travel') ||
        lower.contains('train') ||
        lower.contains('irctc')) {
      return travel;
    }
    if (lower.contains('movie') ||
        lower.contains('cinema') ||
        lower.contains('netflix') ||
        lower.contains('prime') ||
        lower.contains('game') ||
        lower.contains('party') ||
        lower.contains('club') ||
        lower.contains('concert')) {
      return entertainment;
    }
    if (lower.contains('electricity') ||
        lower.contains('bill') ||
        lower.contains('wifi') ||
        lower.contains('internet') ||
        lower.contains('water') ||
        lower.contains('gas') ||
        lower.contains('recharge')) {
      return utilities;
    }
    if (lower.contains('rent') ||
        lower.contains('maintenance') ||
        lower.contains('flat') ||
        lower.contains('room')) {
      return housing;
    }
    if (lower.contains('cloth') ||
        lower.contains('shoes') ||
        lower.contains('amazon') ||
        lower.contains('flipkart') ||
        lower.contains('myntra') ||
        lower.contains('shopping') ||
        lower.contains('mall')) {
      return shopping;
    }
    if (lower.contains('medicine') ||
        lower.contains('doctor') ||
        lower.contains('hospital') ||
        lower.contains('pharmacy') ||
        lower.contains('clinic')) {
      return health;
    }

    return general;
  }
}
