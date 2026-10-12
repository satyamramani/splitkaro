import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
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

  final List<Map<String, dynamic>> _methods = [
    {'name': 'UPI', 'icon': Icons.qr_code_2},
    {'name': 'Cash', 'icon': Icons.payments_outlined},
    {'name': 'Bank', 'icon': Icons.account_balance_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.defaultAmount.toStringAsFixed(2),
    );
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

    final settlementExpense = Expense(
      id: '',
      description: 'Settled up via $_paymentMethod',
      amount: amount,
      payer: widget.debtor,
      splitOwed: {widget.creditor: amount},
      group: widget.group ?? '',
      category: 'settlement',
      date: DateTime.now(),
    );

    final success = await ref.read(expenseProvider.notifier).addExpense(settlementExpense);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settlement of ${AppConstants.formatCurrency(amount)} recorded!'),
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
            const SizedBox(height: 18),

            // Amount field with Rupee symbol (Responsive for mobile)
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

            // Payment mode selector (Clean 3-column on mobile)
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
