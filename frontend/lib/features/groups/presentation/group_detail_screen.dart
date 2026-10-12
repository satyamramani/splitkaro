import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debt_simplifier.dart';
import '../../auth/providers/user_provider.dart';
import '../../expenses/models/expense_category.dart';
import '../../expenses/presentation/settle_up_sheet.dart';
import '../../expenses/presentation/expense_detail_sheet.dart';
import '../../expenses/providers/expense_provider.dart';
import '../models/group.dart';
import '../providers/group_provider.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  final Group? initialGroup;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    this.initialGroup,
  });

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  String? _selectedCategoryFilter;
  bool _showOtherGroupDebts = false;

  @override
  Widget build(BuildContext context) {
    final groupState = ref.watch(groupProvider);
    final group = groupState.groups.firstWhere(
      (g) => g.id == widget.groupId,
      orElse: () => widget.initialGroup ?? Group(id: widget.groupId, name: 'Group', description: '', members: [], created: DateTime.now()),
    );

    final currentUser = ref.watch(currentUserProvider);
    final currentUserName = currentUser.name;

    if (group.members.isNotEmpty && !group.isMember(currentUser)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Access')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Access Restricted',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You are not a member of this group.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to Groups'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    bool isMe(String name) {
      return currentUser.isMe(name);
    }

    final allExpenses = ref.watch(expenseProvider).expenses;
    // Filter expenses specifically for this group
    final groupExpenses = allExpenses.where((e) => e.group == group.name).toList();
    final double totalGroupSpend = groupExpenses.where((e) => !e.isSettlement).fold(0.0, (sum, e) => sum + e.amount);

    // Compute group-specific debts using DebtSimplifier
    final List<Debt> groupRawDebts = [];
    for (final exp in groupExpenses) {
      exp.splitOwed.forEach((person, amountOwed) {
        if (person != exp.payer && amountOwed > 0) {
          groupRawDebts.add(Debt(person, exp.payer, amountOwed));
        }
      });
    }
    final groupSimplifiedDebts = DebtSimplifier.simplifyDebts(groupRawDebts);

    // Calculate user's net balance specifically in this group
    double youOweInGroup = 0;
    double youAreOwedInGroup = 0;
    for (var debt in groupSimplifiedDebts) {
      if (isMe(debt.debtor)) {
        youOweInGroup += debt.amount;
      } else if (isMe(debt.creditor)) {
        youAreOwedInGroup += debt.amount;
      }
    }
    final netGroupBalance = youAreOwedInGroup - youOweInGroup;
    final balanceColor = netGroupBalance > 0.01 
        ? AppTheme.secondaryColor 
        : (netGroupBalance < -0.01 ? AppTheme.errorColor : AppTheme.textSecondaryColor);
    final balancePrefix = netGroupBalance > 0.01 
        ? '+${AppConstants.currencySymbol}' 
        : (netGroupBalance < -0.01 ? '-${AppConstants.currencySymbol}' : AppConstants.currencySymbol);

    // Group category breakdown
    final Map<String, double> categoryTotals = {};
    for (var exp in groupExpenses) {
      if (exp.isSettlement) continue;
      final catId = exp.categoryDetails.id;
      categoryTotals[catId] = (categoryTotals[catId] ?? 0.0) + exp.amount;
    }

    // Filtered group expenses
    final filteredExpenses = _selectedCategoryFilter == null
        ? groupExpenses
        : groupExpenses.where((e) => e.categoryDetails.id == _selectedCategoryFilter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
            tooltip: 'Delete Group',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Group?'),
                  content: Text('Are you sure you want to delete "${group.name}"? Recorded expenses will remain.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(groupProvider.notifier).deleteGroup(group.id);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: () => context.push('/add-expense', extra: group.name),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: Text('Add Expense to ${group.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Group Hero Balance Card
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: balanceColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: balanceColor.withValues(alpha: 0.25), width: 1.5),
              ),
              child: Column(
                children: [
                  Text(
                    'Your balance in ${group.name}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$balancePrefix${netGroupBalance.abs().toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: balanceColor),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Total Spent', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11.5)),
                            const SizedBox(height: 2),
                            Text(
                              AppConstants.formatCurrency(totalGroupSpend),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 28, color: Colors.grey.shade300),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Members', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11.5)),
                            const SizedBox(height: 2),
                            Text(
                              '${group.members.length}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Member Avatars Chips
            const Text('Group Members', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: group.members.map((m) {
                final isMeUser = isMe(m);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: isMeUser ? AppTheme.primaryColor : AppTheme.secondaryColor,
                        child: Text(
                          m.isNotEmpty ? m[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isMeUser ? '$m (You)' : m,
                        style: TextStyle(fontSize: 12.5, fontWeight: isMeUser ? FontWeight.bold : FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Group Settlement Plan (Focused on My Debts)
            Builder(builder: (context) {
              final myGroupDebts = groupSimplifiedDebts.where((d) => isMe(d.debtor) || isMe(d.creditor)).toList();
              final otherGroupDebts = groupSimplifiedDebts.where((d) => !isMe(d.debtor) && !isMe(d.creditor)).toList();

              if (myGroupDebts.isEmpty && otherGroupDebts.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.swap_horiz, color: AppTheme.primaryColor, size: 20),
                          SizedBox(width: 6),
                          Text('Your Group Settlements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (otherGroupDebts.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() => _showOtherGroupDebts = !_showOtherGroupDebts),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          child: Text(
                            _showOtherGroupDebts ? 'Hide other' : 'Other (${otherGroupDebts.length})',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (myGroupDebts.isNotEmpty)
                    Card(
                      elevation: 0,
                      color: AppTheme.surfaceColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                        child: Column(
                          children: myGroupDebts.map((debt) {
                            final debtorIsMe = isMe(debt.debtor);
                            final otherPerson = debtorIsMe ? debt.creditor : debt.debtor;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 15,
                                    backgroundColor: debtorIsMe 
                                        ? AppTheme.errorColor.withValues(alpha: 0.15) 
                                        : AppTheme.secondaryColor.withValues(alpha: 0.15),
                                    child: Text(
                                      otherPerson.isNotEmpty ? otherPerson[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        fontSize: 12, 
                                        color: debtorIsMe ? AppTheme.errorColor : AppTheme.secondaryColor, 
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: RichText(
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      text: TextSpan(
                                        style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 13.5),
                                        children: debtorIsMe
                                            ? [
                                                const TextSpan(text: 'You owe ', style: TextStyle(fontWeight: FontWeight.normal)),
                                                TextSpan(text: otherPerson, style: const TextStyle(fontWeight: FontWeight.bold)),
                                              ]
                                            : [
                                                TextSpan(text: otherPerson, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                const TextSpan(text: ' owes you', style: TextStyle(fontWeight: FontWeight.normal)),
                                              ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        AppConstants.formatCurrency(debt.amount),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: debtorIsMe
                                              ? AppTheme.errorColor
                                              : AppTheme.secondaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      InkWell(
                                        onTap: () {
                                          SettleUpSheet.show(
                                            context,
                                            debtor: debt.debtor,
                                            creditor: debt.creditor,
                                            defaultAmount: debt.amount,
                                            group: group.name,
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                                          decoration: BoxDecoration(
                                            color: debtorIsMe 
                                                ? AppTheme.primaryColor.withValues(alpha: 0.1) 
                                                : AppTheme.secondaryColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: debtorIsMe 
                                                  ? AppTheme.primaryColor.withValues(alpha: 0.35) 
                                                  : AppTheme.secondaryColor.withValues(alpha: 0.35),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                debtorIsMe ? Icons.check_circle_outline_rounded : Icons.handshake_outlined, 
                                                size: 13, 
                                                color: debtorIsMe ? AppTheme.primaryColor : AppTheme.secondaryColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                debtorIsMe ? 'Settle Up' : 'Settle',
                                                style: TextStyle(
                                                  fontSize: 11.5, 
                                                  fontWeight: FontWeight.bold, 
                                                  color: debtorIsMe ? AppTheme.primaryColor : AppTheme.secondaryColor,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.secondaryColor.withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: AppTheme.secondaryColor, size: 18),
                          SizedBox(width: 8),
                          Text('You have no pending debts in this group', style: TextStyle(fontSize: 12.5, color: AppTheme.secondaryColor, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),

                  if (_showOtherGroupDebts && otherGroupDebts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Other Members\' Settlements', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
                          const SizedBox(height: 6),
                          ...otherGroupDebts.map((debt) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${debt.debtor} owes ${debt.creditor}', style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimaryColor)),
                                Text(AppConstants.formatCurrency(debt.amount), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              );
            }),

            // Group Category Spending Breakdown
            if (categoryTotals.isNotEmpty) ...[
              const Text('Spending by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: FilterChip(
                        selected: _selectedCategoryFilter == null,
                        showCheckmark: false,
                        label: Text(
                          'All (${groupExpenses.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _selectedCategoryFilter == null ? FontWeight.bold : FontWeight.w500,
                            color: _selectedCategoryFilter == null ? Colors.white : AppTheme.textPrimaryColor,
                          ),
                        ),
                        selectedColor: AppTheme.primaryColor,
                        backgroundColor: AppTheme.surfaceColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: _selectedCategoryFilter == null ? AppTheme.primaryColor : Colors.grey.shade300,
                          ),
                        ),
                        onSelected: (_) => setState(() => _selectedCategoryFilter = null),
                      ),
                    ),
                    ...ExpenseCategory.allCategories
                        .where((cat) => (categoryTotals[cat.id] ?? 0) > 0)
                        .map((cat) {
                      final isSelected = _selectedCategoryFilter == cat.id;
                      final total = categoryTotals[cat.id] ?? 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: FilterChip(
                          selected: isSelected,
                          showCheckmark: false,
                          avatar: Icon(cat.icon, size: 14, color: isSelected ? Colors.white : cat.color),
                          label: Text(
                            '${cat.name} • ${AppConstants.formatCurrency(total)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
                            ),
                          ),
                          selectedColor: cat.color,
                          backgroundColor: cat.color.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: isSelected ? cat.color : cat.color.withValues(alpha: 0.25)),
                          ),
                          onSelected: (_) => setState(() {
                            _selectedCategoryFilter = isSelected ? null : cat.id;
                          }),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Group Expenses Feed Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Group Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  '${filteredExpenses.length} ${filteredExpenses.length == 1 ? "expense" : "expenses"}',
                  style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Group Expenses List
            if (filteredExpenses.isEmpty)
              Container(
                padding: const EdgeInsets.all(28.0),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 44, color: AppTheme.textSecondaryColor),
                    const SizedBox(height: 10),
                    Text(
                      _selectedCategoryFilter != null 
                          ? 'No expenses in this category' 
                          : 'No expenses in ${group.name} yet',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "+ Add Expense to ${group.name}" below to split a bill.',
                      style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredExpenses.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final exp = filteredExpenses[index];
                  final isPayer = isMe(exp.payer);
                  final isSettlement = exp.isSettlement;
                  final category = exp.categoryDetails;

                  double myShare = 0.0;
                  exp.splitOwed.forEach((key, val) {
                    if (isMe(key)) myShare += val;
                  });

                  final double youLent = isPayer ? (exp.amount - myShare) : 0.0;
                  final double youBorrowed = !isPayer ? myShare : 0.0;
                  final bool notInvolved = !isPayer && myShare == 0.0;

                  return Dismissible(
                    key: Key(exp.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: AppTheme.errorColor,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (dir) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Record?'),
                          content: Text('Are you sure you want to delete "${exp.description}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (_) {
                      ref.read(expenseProvider.notifier).deleteExpense(exp.id);
                    },
                    child: ListTile(
                      onTap: () => ExpenseDetailSheet.show(context, exp),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: category.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(category.icon, color: category.color, size: 22),
                      ),
                      title: Text(
                        exp.description,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: category.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                category.name,
                                style: TextStyle(fontSize: 10, color: category.color, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${isPayer ? "You" : exp.payer} paid ${AppConstants.formatCurrency(exp.amount)} • ${DateFormat('MMM d').format(exp.date)}',
                                style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (isSettlement) ...[
                            const Text('Settled', style: TextStyle(fontSize: 11, color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                            Text(
                              AppConstants.formatCurrency(exp.amount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.secondaryColor),
                            ),
                          ] else if (isPayer) ...[
                            const Text('You lent', style: TextStyle(fontSize: 11, color: AppTheme.secondaryColor, fontWeight: FontWeight.w600)),
                            Text(
                              '+${AppConstants.formatCurrency(youLent)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.secondaryColor),
                            ),
                          ] else if (notInvolved) ...[
                            const Text('Not involved', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                            Text(
                              AppConstants.formatCurrency(0),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textSecondaryColor),
                            ),
                          ] else ...[
                            const Text('You borrowed', style: TextStyle(fontSize: 11, color: AppTheme.errorColor, fontWeight: FontWeight.w600)),
                            Text(
                              '-${AppConstants.formatCurrency(youBorrowed)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.errorColor),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
