import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debt_simplifier.dart';
import '../../auth/providers/user_provider.dart';
import '../../expenses/models/expense_category.dart';
import '../../expenses/presentation/settle_up_sheet.dart';
import '../../expenses/presentation/expense_detail_sheet.dart';
import '../../expenses/presentation/widgets/expense_activity_card.dart';
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

  void _showManageMembersSheet(BuildContext context, Group currentGroup) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => _ManageMembersSheet(
        initialGroup: currentGroup,
        onRemoveMember: (memberName, isMeUser) async {
          final removed = await _confirmRemoveMember(context, currentGroup, memberName, isMeUser);
          if (removed && isMeUser && bottomSheetContext.mounted) {
            Navigator.pop(bottomSheetContext);
          }
        },
      ),
    );
  }

  Future<bool> _confirmRemoveMember(BuildContext context, Group group, String memberName, bool isMeUser) async {
    final title = isMeUser ? 'Leave Group?' : 'Remove Member?';
    final content = isMeUser
        ? 'Are you sure you want to leave "${group.name}"? You will lose access to this group until added back.'
        : 'Are you sure you want to remove "$memberName" from "${group.name}"?';
    final actionText = isMeUser ? 'Leave' : 'Remove';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: Text(actionText),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref.read(groupProvider.notifier).removeMemberFromGroup(group.id, memberName);
      if (!context.mounted) return true;

      if (success) {
        if (isMeUser) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You left ${group.name}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$memberName removed from ${group.name}')),
          );
        }
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update group members.')),
        );
      }
    }
    return false;
  }

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
                const Icon(Icons.lock_outline, size: 64, color: AppTheme.textSecondaryColor),
                const SizedBox(height: 16),
                const Text(
                  'Access Restricted',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You are not a member of this group.',
                  style: TextStyle(color: AppTheme.textSecondaryColor),
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
          groupRawDebts.add(Debt(person, exp.payer, amountOwed, group: group.name));
        }
      });
    }
    final groupSimplifiedDebts = DebtSimplifier.simplifyDebts(groupRawDebts, group: group.name);

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
            icon: const Icon(Icons.group_outlined),
            tooltip: 'Manage Members',
            onPressed: () => _showManageMembersSheet(context, group),
          ),
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
          decoration: const BoxDecoration(
            color: AppTheme.darkSurface,
            border: Border(
              top: BorderSide(color: AppTheme.darkBorder, width: 1.0),
            ),
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    balanceColor.withValues(alpha: 0.14),
                    AppTheme.darkCard,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: balanceColor.withValues(alpha: 0.35), width: 1.2),
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
                      Container(width: 1, height: 28, color: AppTheme.darkBorder),
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

            // Group Members Card (Clean & Elegant)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.people_outline, size: 16, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Members • ${group.members.length}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => _showManageMembersSheet(context, group),
                        icon: const Icon(Icons.person_add_alt_1, size: 15),
                        label: const Text('Manage', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // Quick Add Member Button
                        Padding(
                          padding: const EdgeInsets.only(right: 14.0),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: () => _showManageMembersSheet(context, group),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(Icons.add, color: AppTheme.primaryColor, size: 20),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Add',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Current Member Avatars
                        ...group.members.map((m) {
                          final isMeUser = isMe(m);
                          final initial = m.isNotEmpty ? m[0].toUpperCase() : '?';
                          return Padding(
                            padding: const EdgeInsets.only(right: 14.0),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _showManageMembersSheet(context, group),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: isMeUser 
                                        ? AppTheme.primaryColor 
                                        : AppTheme.secondaryColor.withValues(alpha: 0.85),
                                    child: Text(
                                      initial,
                                      style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    isMeUser ? 'You' : (m.length > 8 ? '${m.substring(0, 7)}…' : m),
                                    style: TextStyle(
                                      fontSize: 11.5, 
                                      fontWeight: isMeUser ? FontWeight.bold : FontWeight.w500,
                                      color: isMeUser ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
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
                      color: AppTheme.darkCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppTheme.darkBorder),
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
                        color: AppTheme.darkCardElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.darkBorder),
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
                            color: _selectedCategoryFilter == null ? Colors.white : AppTheme.textSecondaryColor,
                          ),
                        ),
                        selectedColor: AppTheme.primaryColor,
                        backgroundColor: AppTheme.darkCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: _selectedCategoryFilter == null ? AppTheme.primaryColor : AppTheme.darkBorder,
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
                              color: isSelected ? Colors.white : AppTheme.textSecondaryColor,
                            ),
                          ),
                          selectedColor: cat.color,
                          backgroundColor: cat.color.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: isSelected ? cat.color : AppTheme.darkBorder),
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
                const Text('Group Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  '${filteredExpenses.length} ${filteredExpenses.length == 1 ? "expense" : "expenses"}',
                  style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12.5),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Group Expenses List
            if (filteredExpenses.isEmpty)
              Container(
                padding: const EdgeInsets.all(28.0),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.darkBorder),
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
              ...filteredExpenses.map((exp) {
                return ExpenseActivityCard(
                  expense: exp,
                  isMe: isMe,
                  showGroupBadge: false,
                  onTap: () => ExpenseDetailSheet.show(context, exp),
                  confirmDismiss: () async {
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
                    ) ?? false;
                  },
                  onDismissed: () {
                    ref.read(expenseProvider.notifier).deleteExpense(exp.id);
                  },
                );
              }),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _ManageMembersSheet extends ConsumerStatefulWidget {
  final Group initialGroup;
  final Function(String memberName, bool isMeUser) onRemoveMember;

  const _ManageMembersSheet({
    required this.initialGroup,
    required this.onRemoveMember,
  });

  @override
  ConsumerState<_ManageMembersSheet> createState() => _ManageMembersSheetState();
}

class _ManageMembersSheetState extends ConsumerState<_ManageMembersSheet> {
  late final TextEditingController _nameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addMember(String name) async {
    final clean = name.trim();
    if (clean.isEmpty || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(usersProvider.notifier).addUser(clean);
      final success = await ref.read(groupProvider.notifier).addMemberToGroup(widget.initialGroup.id, clean);
      if (mounted) {
        _nameController.clear();
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$clean added to group!'),
              backgroundColor: AppTheme.secondaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupProvider).groups;
    final group = groups.firstWhere(
      (g) => g.id == widget.initialGroup.id,
      orElse: () => widget.initialGroup,
    );
    final currentUser = ref.watch(currentUserProvider);
    final allUsers = ref.watch(usersProvider).users;
    final nonMembers = allUsers.where((u) => !group.members.any((m) => u.isMe(m))).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Group Members',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${group.members.length} people in ${group.name}',
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryColor),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondaryColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // Add Member Input Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCardElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_add_outlined, color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            hintText: 'Add friend by name...',
                            hintStyle: TextStyle(fontSize: 13.5, color: AppTheme.textMuted),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onSubmitted: (val) => _addMember(val),
                        ),
                      ),
                      FilledButton(
                        onPressed: _isLoading ? null : () => _addMember(_nameController.text),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Add', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Quick Add Suggestions
                if (nonMembers.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: AppTheme.primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'Quick Add from Friends',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondaryColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: nonMembers.map((u) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ActionChip(
                            elevation: 0,
                            avatar: CircleAvatar(
                              radius: 11,
                              backgroundColor: AppTheme.primaryColor,
                              child: Text(
                                u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(u.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 4),
                                const Icon(Icons.add, size: 14, color: AppTheme.primaryColor),
                              ],
                            ),
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
                            side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            onPressed: () => _addMember(u.name),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Current Members Section
                Text(
                  'Current Members (${group.members.length})',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondaryColor,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: group.members.length,
                    separatorBuilder: (context, i) => const Divider(height: 1, color: AppTheme.darkBorderSubtle),
                    itemBuilder: (context, index) {
                      final m = group.members[index];
                      final isMeUser = currentUser.isMe(m);
                      final initial = m.isNotEmpty ? m[0].toUpperCase() : '?';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: isMeUser
                              ? AppTheme.primaryColor
                              : AppTheme.secondaryColor.withValues(alpha: 0.85),
                          child: Text(
                            initial,
                            style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              m,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isMeUser ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            if (isMeUser) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'You',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            isMeUser ? Icons.logout : Icons.remove_circle_outline,
                            color: isMeUser ? Colors.orange.shade700 : AppTheme.errorColor.withValues(alpha: 0.7),
                            size: 20,
                          ),
                          tooltip: isMeUser ? 'Leave group' : 'Remove $m',
                          onPressed: () => widget.onRemoveMember(m, isMeUser),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
