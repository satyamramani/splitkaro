import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debt_simplifier.dart';
import '../../groups/providers/group_provider.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';

class SettleUpSheet extends ConsumerStatefulWidget {
  final String debtor;
  final String creditor;
  final double defaultAmount;
  final String? group;

  const SettleUpSheet({
    super.key,
    required this.debtor,
    required this.creditor,
    required this.defaultAmount,
    this.group,
  });

  static Future<void> show(
    BuildContext context, {
    required String debtor,
    required String creditor,
    required double defaultAmount,
    String? group,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SettleUpSheet(
        debtor: debtor,
        creditor: creditor,
        defaultAmount: defaultAmount,
        group: group,
      ),
    );
  }

  @override
  ConsumerState<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends ConsumerState<SettleUpSheet> {
  late final TextEditingController _amountController;
  String _paymentMethod = 'UPI';
  bool _isSaving = false;
  String? _selectedGroup;
  Map<String, double> _outstandingGroupDebts = {};

  final List<Map<String, dynamic>> _methods = [
    {'name': 'UPI', 'icon': Icons.qr_code_2},
    {'name': 'Cash', 'icon': Icons.payments_outlined},
    {'name': 'Bank', 'icon': Icons.account_balance_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.group;
    _amountController = TextEditingController(
      text: widget.defaultAmount > 0.009 ? widget.defaultAmount.toStringAsFixed(2) : '',
    );

    // Compute outstanding debts across groups for this debtor & creditor
    final allExpenses = ref.read(expenseProvider).expenses;
    _outstandingGroupDebts = DebtSimplifier.getOutstandingGroupDebts(
      allExpenses: allExpenses,
      debtor: widget.debtor,
      creditor: widget.creditor,
    );

    if (_selectedGroup == null || _selectedGroup!.isEmpty) {
      if (_outstandingGroupDebts.length == 1) {
        // Exactly one group has debt: automatically pick it!
        _selectedGroup = _outstandingGroupDebts.keys.first;
        if (widget.defaultAmount <= 0.009) {
          _amountController.text = _outstandingGroupDebts.values.first.toStringAsFixed(2);
        }
      } else if (_outstandingGroupDebts.length > 1) {
        // Multiple groups have debt: default to '__all__' (auto-split)
        _selectedGroup = '__all__';
      } else {
        // Fallback: check if debtor & creditor share a group
        final groups = ref.read(groupProvider).groups;
        final dNorm = widget.debtor.trim().toLowerCase();
        final cNorm = widget.creditor.trim().toLowerCase();
        final sharedGroups = groups.where((g) =>
          g.members.any((m) => m.trim().toLowerCase() == dNorm) &&
          g.members.any((m) => m.trim().toLowerCase() == cNorm)
        ).toList();

        if (sharedGroups.length == 1) {
          _selectedGroup = sharedGroups.first.name;
        } else {
          _selectedGroup = ''; // Direct
        }
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _recordSettlement() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid settlement amount.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    bool success = true;

    if (_selectedGroup == '__all__') {
      final allExpenses = ref.read(expenseProvider).expenses;
      final groupDebts = DebtSimplifier.getOutstandingGroupDebts(
        allExpenses: allExpenses,
        debtor: widget.debtor,
        creditor: widget.creditor,
      );

      double remaining = amount;
      for (final entry in groupDebts.entries) {
        if (remaining <= 0.009) break;
        final portion = remaining < entry.value ? remaining : entry.value;
        remaining -= portion;

        final expense = Expense(
          id: '',
          description: 'Settled up via $_paymentMethod',
          amount: portion,
          payer: widget.debtor,
          splitOwed: {widget.creditor: portion},
          group: entry.key,
          category: 'settlement',
          date: DateTime.now(),
        );

        final res = await ref.read(expenseProvider.notifier).addExpense(expense);
        if (!res) success = false;
      }

      if (remaining > 0.009) {
        final expense = Expense(
          id: '',
          description: 'Settled up via $_paymentMethod',
          amount: remaining,
          payer: widget.debtor,
          splitOwed: {widget.creditor: remaining},
          group: groupDebts.isNotEmpty ? groupDebts.keys.first : '',
          category: 'settlement',
          date: DateTime.now(),
        );
        final res = await ref.read(expenseProvider.notifier).addExpense(expense);
        if (!res) success = false;
      }
    } else {
      final settlementExpense = Expense(
        id: '',
        description: 'Settled up via $_paymentMethod',
        amount: amount,
        payer: widget.debtor,
        splitOwed: {widget.creditor: amount},
        group: _selectedGroup ?? '',
        category: 'settlement',
        date: DateTime.now(),
      );

      success = await ref.read(expenseProvider.notifier).addExpense(settlementExpense);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Settlement of ${AppConstants.formatCurrency(amount)} recorded${_selectedGroup != null && _selectedGroup!.isNotEmpty && _selectedGroup != "__all__" ? " in $_selectedGroup" : ""}!',
            ),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to record settlement.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final cs = Theme.of(context).colorScheme;
    final groups = ref.watch(groupProvider).groups;
    final dNorm = widget.debtor.trim().toLowerCase();
    final cNorm = widget.creditor.trim().toLowerCase();

    // Groups that either have outstanding debt or share both members
    final Set<String> groupNames = {};
    for (final k in _outstandingGroupDebts.keys) {
      if (k.isNotEmpty) groupNames.add(k);
    }
    for (final g in groups) {
      final isMemberD = g.members.any((m) => m.trim().toLowerCase() == dNorm);
      final isMemberC = g.members.any((m) => m.trim().toLowerCase() == cNorm);
      if (isMemberD && isMemberC) {
        groupNames.add(g.name);
      }
    }
    if (widget.group != null && widget.group!.isNotEmpty) {
      groupNames.add(widget.group!);
    }

    final List<DropdownMenuItem<String>> groupItems = [];

    if (_outstandingGroupDebts.length > 1) {
      groupItems.add(
        DropdownMenuItem<String>(
          value: '__all__',
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('All Groups (Auto-split)', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(
                AppConstants.formatCurrency(widget.defaultAmount),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    for (final g in groupNames) {
      final debtAmount = _outstandingGroupDebts[g];
      groupItems.add(
        DropdownMenuItem<String>(
          value: g,
          child: Row(
            children: [
              const Icon(Icons.group_outlined, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(g, style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
              if (debtAmount != null && debtAmount > 0.01)
                Text(
                  'Owes ${AppConstants.formatCurrency(debtAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.errorColor, fontSize: 11.5),
                ),
            ],
          ),
        ),
      );
    }

    // Direct / Non-group option
    final directDebt = _outstandingGroupDebts[''];
    groupItems.add(
      DropdownMenuItem<String>(
        value: '',
        child: Row(
          children: [
            const Icon(Icons.person_outline, size: 16, color: AppTheme.textSecondaryColor),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Direct (No group)'),
            ),
            if (directDebt != null && directDebt > 0.01)
              Text(
                'Owes ${AppConstants.formatCurrency(directDebt)}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.errorColor, fontSize: 11.5),
              ),
          ],
        ),
      ),
    );

    // Make sure _selectedGroup is valid
    final bool isSelectedValid = _selectedGroup == '__all__' ||
        _selectedGroup == '' ||
        groupNames.contains(_selectedGroup);
    final effectiveGroup = isSelectedValid ? _selectedGroup : '';

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Record Settlement',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.debtor,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor, fontSize: 13.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.0),
                      child: Icon(Icons.arrow_forward, size: 14, color: AppTheme.secondaryColor),
                    ),
                    Flexible(
                      child: Text(
                        widget.creditor,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor, fontSize: 13.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Group Destination Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.darkCardElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: effectiveGroup,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
                  dropdownColor: AppTheme.darkCardElevated,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                  items: groupItems,
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _selectedGroup = val;
                      if (val == '__all__') {
                        _amountController.text = widget.defaultAmount.toStringAsFixed(2);
                      } else if (_outstandingGroupDebts.containsKey(val)) {
                        _amountController.text = _outstandingGroupDebts[val]!.toStringAsFixed(2);
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Amount field with Rupee symbol
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  AppConstants.currencySymbol,
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 80, maxWidth: 200),
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Payment mode selector
            const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: _methods.map((m) {
                final isSelected = _paymentMethod == m['name'];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    child: InkWell(
                      onTap: () => setState(() => _paymentMethod = m['name'] as String),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.12) : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryColor : cs.outline,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              m['icon'] as IconData,
                              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                              size: 22,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              m['name'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),

            // Save button
            FilledButton.icon(
              onPressed: _isSaving ? null : _recordSettlement,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: Text(
                _isSaving ? 'Recording...' : 'Record Payment',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

