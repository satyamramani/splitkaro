import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debt_simplifier.dart';
import '../../auth/providers/user_provider.dart';
import '../../expenses/presentation/expense_detail_sheet.dart';
import '../../expenses/presentation/widgets/expense_activity_card.dart';
import '../../expenses/providers/expense_provider.dart';
import '../providers/group_provider.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  Future<void> _showCreateGroupDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final users = ref.read(usersProvider).users;
    final currentUser = ref.read(currentUserProvider);
    final currentUserName = currentUser.name;

    final Set<String> selectedMembers = {currentUserName};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Group', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'e.g. Goa Trip, Flat 402',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'e.g. Vacation expenses',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Select Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ...users.map((u) {
                  final isMe = u.name == currentUserName;
                  final isChecked = selectedMembers.contains(u.name);
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: isChecked,
                    title: Text(isMe ? '${u.name} (You)' : u.name),
                    onChanged: isMe
                        ? null
                        : (val) {
                            setState(() {
                              if (val == true) {
                                selectedMembers.add(u.name);
                              } else {
                                selectedMembers.remove(u.name);
                              }
                            });
                          },
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                await ref.read(groupProvider.notifier).createGroup(
                  name,
                  descController.text.trim(),
                  selectedMembers.toList(),
                );
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDirectExpenses(BuildContext context, WidgetRef ref) {
    final currentUser = ref.read(currentUserProvider);
    final directExpenses = ref.read(expenseProvider).expenses.where((e) =>
      e.group.isEmpty && (currentUser.isMe(e.payer) || e.splitOwed.keys.any((p) => currentUser.isMe(p)))
    ).toList();
    final double totalDirectSpend = directExpenses.where((e) => !e.isSettlement).fold(0.0, (sum, e) => sum + e.amount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
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
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.15),
                    child: const Icon(Icons.person_pin_circle_outlined, color: AppTheme.secondaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Direct / Non-Group Expenses',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Total: ${AppConstants.formatCurrency(totalDirectSpend)} • ${directExpenses.length} expenses',
                          style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: directExpenses.isEmpty
                    ? const Center(
                        child: Text('No direct non-group expenses yet', style: TextStyle(color: AppTheme.textSecondaryColor)),
                      )
                    : ListView.builder(
                        itemCount: directExpenses.length,
                        itemBuilder: (context, index) {
                          final exp = directExpenses[index];
                          return ExpenseActivityCard(
                            expense: exp,
                            isMe: (name) => currentUser.isMe(name),
                            showGroupBadge: false,
                            onTap: () {
                              Navigator.pop(ctx);
                              ExpenseDetailSheet.show(context, exp);
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/add-expense');
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Direct Expense'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupState = ref.watch(groupProvider);
    final currentUser = ref.watch(currentUserProvider);
    final groups = ref.watch(userGroupsProvider);
    final allExpenses = ref.watch(expenseProvider).expenses;
    final cs = Theme.of(context).colorScheme;

    // Only show direct expenses that involve currentUser
    final directExpenses = allExpenses.where((e) =>
      e.group.isEmpty && (currentUser.isMe(e.payer) || e.splitOwed.keys.any((p) => currentUser.isMe(p)))
    ).toList();
    final double totalDirectSpend = directExpenses.where((e) => !e.isSettlement).fold(0.0, (sum, e) => sum + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Create Group',
            onPressed: () => _showCreateGroupDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(groupProvider.notifier).refresh();
              ref.read(expenseProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: groupState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Direct / Non-Group Expenses Card
                Card(
                  elevation: 0,
                  color: AppTheme.secondaryColor.withValues(alpha: 0.07),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppTheme.secondaryColor.withValues(alpha: 0.25)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showDirectExpenses(context, ref),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person_pin_circle_outlined, color: AppTheme.secondaryColor, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Direct Expenses',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Non-group splits • ${directExpenses.length} expenses',
                                  style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Total spend', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
                              Text(
                                AppConstants.formatCurrency(totalDirectSpend),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.secondaryColor),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, color: AppTheme.textSecondaryColor, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Groups Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Your Groups', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () => _showCreateGroupDialog(context, ref),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (groups.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28.0),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outline),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.groups_outlined, size: 48, color: AppTheme.textSecondaryColor),
                        const SizedBox(height: 10),
                        const Text('No groups yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text(
                          'Create a group for your apartment, trip, or flatmates.',
                          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _showCreateGroupDialog(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text('Create a Group'),
                        ),
                      ],
                    ),
                  )
                else
                  ...groups.map((group) {
                    final groupExpenses = allExpenses.where((e) => e.group == group.name).toList();

                    // Compute simplified debts for this group using all expenses (including settlements)
                    final rawDebts = <Debt>[];
                    for (final exp in groupExpenses) {
                      exp.splitOwed.forEach((person, amountOwed) {
                        if (person != exp.payer && amountOwed > 0) {
                          rawDebts.add(Debt(person, exp.payer, amountOwed, group: group.name));
                        }
                      });
                    }
                    final groupDebts = DebtSimplifier.simplifyDebts(rawDebts, group: group.name);

                    // Net balance from current user's perspective
                    double myNet = 0.0;
                    for (final d in groupDebts) {
                      if (currentUser.isMe(d.debtor)) myNet -= d.amount;
                      if (currentUser.isMe(d.creditor)) myNet += d.amount;
                    }

                    final bool isSettled = myNet.abs() < 0.01;
                    final bool iOwe = myNet < -0.01;
                    final Color balanceColor = isSettled
                        ? AppTheme.textSecondaryColor
                        : iOwe
                            ? AppTheme.errorColor
                            : AppTheme.successColor;
                    final String balanceLabel = isSettled
                        ? 'All settled'
                        : iOwe
                            ? 'You owe ${AppConstants.formatCurrency(myNet.abs())}'
                            : 'You get back ${AppConstants.formatCurrency(myNet)}';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Card(
                        elevation: 0,
                        color: AppTheme.darkCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppTheme.darkBorder, width: 1),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => context.push('/group-detail/${group.id}', extra: group),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(Icons.group_outlined, color: AppTheme.primaryColor, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '${group.members.length} members • ${groupExpenses.length} expenses',
                                        style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      balanceLabel,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: balanceColor,
                                      ),
                                    ),
                                    if (isSettled)
                                      const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.textSecondaryColor),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, color: AppTheme.textSecondaryColor, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 80), // FAB safe area
              ],
            ),
    );
  }
}
