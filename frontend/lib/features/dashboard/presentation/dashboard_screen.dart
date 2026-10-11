import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/debt_simplifier.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/group_provider.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/models/expense_category.dart';
import '../../expenses/presentation/settle_up_sheet.dart';
import '../../expenses/presentation/expense_detail_sheet.dart';
import '../../expenses/providers/expense_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'main_layout.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _selectedCategoryFilter; // null means 'All'
  String? _selectedGroupFilter; // null means 'All', '__direct__' means Direct / Non-group, or group name
  int _visibleActivityCount = 10; // Lazy pagination: load 10 items initially for instant rendering

  @override
  Widget build(BuildContext context) {
    final groupState = ref.watch(groupProvider);
    final groups = groupState.groups;
    final expenseState = ref.watch(expenseProvider);
    final expenses = expenseState.expenses;
    final simplifiedDebts = ref.watch(simplifiedDebtsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final currentUserName = currentUser.name;

    bool isMe(String name) {
      final n = name.trim().toLowerCase();
      return n == currentUserName.toLowerCase() || 
             n == 'you' || 
             n == 'satyam' ||
             (currentUser.email.isNotEmpty && n == currentUser.email.toLowerCase()) ||
             n == currentUser.id.toLowerCase();
    }

    // 1. Group-filtered scope of expenses
    final List<Expense> scopeExpenses;
    if (_selectedGroupFilter == null) {
      scopeExpenses = expenses;
    } else if (_selectedGroupFilter == '__direct__') {
      scopeExpenses = expenses.where((exp) => exp.group.isEmpty).toList();
    } else {
      scopeExpenses = expenses.where((exp) => exp.group == _selectedGroupFilter).toList();
    }

    // 2. Debts for this specific group scope
    final List<Debt> activeSimplifiedDebts;
    if (_selectedGroupFilter == null) {
      activeSimplifiedDebts = simplifiedDebts;
    } else {
      final List<Debt> scopeRawDebts = [];
      for (final exp in scopeExpenses) {
        exp.splitOwed.forEach((person, amountOwed) {
          if (person != exp.payer && amountOwed > 0) {
            scopeRawDebts.add(Debt(person, exp.payer, amountOwed));
          }
        });
      }
      activeSimplifiedDebts = DebtSimplifier.simplifyDebts(scopeRawDebts);
    }

    // 3. Category spending & totals calculation on scopeExpenses
    final Map<String, double> categoryTotals = {};
    final Map<String, double> categoryMyShareTotals = {};
    final Map<String, int> categoryCounts = {};
    double grandTotalExpenses = 0.0;

    for (var exp in scopeExpenses) {
      if (exp.isSettlement) continue;
      final catId = exp.categoryDetails.id;
      categoryTotals[catId] = (categoryTotals[catId] ?? 0.0) + exp.amount;
      categoryCounts[catId] = (categoryCounts[catId] ?? 0) + 1;
      grandTotalExpenses += exp.amount;

      double myShare = 0.0;
      exp.splitOwed.forEach((key, val) {
        if (isMe(key)) myShare += val;
      });
      categoryMyShareTotals[catId] = (categoryMyShareTotals[catId] ?? 0.0) + myShare;
    }

    // 4. Filtered expenses based on selected category on top of scopeExpenses
    final filteredExpenses = _selectedCategoryFilter == null
        ? scopeExpenses
        : scopeExpenses.where((exp) => exp.categoryDetails.id == _selectedCategoryFilter).toList();

    double youOwe = 0;
    double youAreOwed = 0;

    for (var debt in activeSimplifiedDebts) {
      if (isMe(debt.debtor)) {
        youOwe += debt.amount;
      } else if (isMe(debt.creditor)) {
        youAreOwed += debt.amount;
      }
    }

    final totalBalance = youAreOwed - youOwe;
    final balanceColor = totalBalance > 0.01 
        ? AppTheme.secondaryColor 
        : (totalBalance < -0.01 ? AppTheme.errorColor : AppTheme.textSecondaryColor);
    final balancePrefix = totalBalance > 0.01 
        ? '+${AppConstants.currencySymbol}' 
        : (totalBalance < -0.01 ? '-${AppConstants.currencySymbol}' : AppConstants.currencySymbol);

    String balanceTitle = 'Total Balance';
    if (_selectedGroupFilter == '__direct__') {
      balanceTitle = 'Direct / Non-Group Balance';
    } else if (_selectedGroupFilter != null) {
      balanceTitle = '$_selectedGroupFilter Balance';
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
            Text(
              'Hi, $currentUserName', 
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(expenseProvider.notifier).refresh();
              ref.read(usersProvider.notifier).refresh();
              ref.read(groupProvider.notifier).refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(expenseProvider.notifier).refresh();
          await ref.read(usersProvider.notifier).refresh();
          await ref.read(groupProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Group Filter Bar (Quick switch between Groups and Direct)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    FilterChip(
                      selected: _selectedGroupFilter == null,
                      showCheckmark: false,
                      avatar: Icon(
                        Icons.layers_outlined, 
                        size: 15, 
                        color: _selectedGroupFilter == null ? Colors.white : AppTheme.textSecondaryColor,
                      ),
                      label: const Text('All Groups', style: TextStyle(fontSize: 12.5)),
                      labelStyle: TextStyle(
                        fontWeight: _selectedGroupFilter == null ? FontWeight.bold : FontWeight.w500,
                        color: _selectedGroupFilter == null ? Colors.white : AppTheme.textPrimaryColor,
                      ),
                      selectedColor: AppTheme.primaryColor,
                      backgroundColor: AppTheme.surfaceColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: _selectedGroupFilter == null ? AppTheme.primaryColor : Colors.grey.shade300),
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedGroupFilter = null;
                          _selectedCategoryFilter = null;
                          _visibleActivityCount = 10;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ...groups.map((g) {
                      final isSelected = _selectedGroupFilter == g.name;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          selected: isSelected,
                          showCheckmark: false,
                          avatar: Icon(
                            Icons.group_outlined, 
                            size: 15, 
                            color: isSelected ? Colors.white : AppTheme.primaryColor,
                          ),
                          label: Text(g.name, style: const TextStyle(fontSize: 12.5)),
                          labelStyle: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
                          ),
                          selectedColor: AppTheme.primaryColor,
                          backgroundColor: AppTheme.surfaceColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300),
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedGroupFilter = isSelected ? null : g.name;
                              _selectedCategoryFilter = null;
                              _visibleActivityCount = 10;
                            });
                          },
                        ),
                      );
                    }),
                    FilterChip(
                      selected: _selectedGroupFilter == '__direct__',
                      showCheckmark: false,
                      avatar: Icon(
                        Icons.person_pin_circle_outlined, 
                        size: 15, 
                        color: _selectedGroupFilter == '__direct__' ? Colors.white : AppTheme.secondaryColor,
                      ),
                      label: const Text('Direct / Non-Group', style: TextStyle(fontSize: 12.5)),
                      labelStyle: TextStyle(
                        fontWeight: _selectedGroupFilter == '__direct__' ? FontWeight.bold : FontWeight.w500,
                        color: _selectedGroupFilter == '__direct__' ? Colors.white : AppTheme.textPrimaryColor,
                      ),
                      selectedColor: AppTheme.secondaryColor,
                      backgroundColor: AppTheme.surfaceColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: _selectedGroupFilter == '__direct__' ? AppTheme.secondaryColor : Colors.grey.shade300),
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedGroupFilter = _selectedGroupFilter == '__direct__' ? null : '__direct__';
                          _selectedCategoryFilter = null;
                          _visibleActivityCount = 10;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Animated Balance Card (Mobile Responsive)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: balanceColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: balanceColor.withValues(alpha: 0.25), width: 1.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                child: Column(
                  children: [
                    Text(balanceTitle, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          '$balancePrefix${totalBalance.abs().toStringAsFixed(2)}', 
                          key: ValueKey(totalBalance),
                          style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: balanceColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Text('You owe', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  AppConstants.formatCurrency(youOwe), 
                                  style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 32, color: Colors.grey.shade300),
                        Expanded(
                          child: Column(
                            children: [
                              const Text('You are owed', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  AppConstants.formatCurrency(youAreOwed), 
                                  style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),

              // Contextual Group Action Banner (shown when a specific group or direct filter is active)
              if (_selectedGroupFilter != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedGroupFilter == '__direct__' ? Icons.person_pin_circle_outlined : Icons.group_work_outlined,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedGroupFilter == '__direct__' 
                              ? 'Direct Expenses' 
                              : _selectedGroupFilter!,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          if (_selectedGroupFilter == '__direct__') {
                            context.push('/add-expense');
                          } else {
                            context.push('/add-expense', extra: _selectedGroupFilter);
                          }
                        },
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          backgroundColor: AppTheme.primaryColor,
                        ),
                        icon: const Icon(Icons.add, size: 14),
                        label: Text(
                          _selectedGroupFilter == '__direct__' ? 'Add Direct' : 'Add to Group',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_selectedGroupFilter != '__direct__') ...[
                        const SizedBox(width: 6),
                        Builder(builder: (ctx) {
                          final g = groups.firstWhere(
                            (item) => item.name == _selectedGroupFilter, 
                            orElse: () => Group(id: '', name: '', description: '', members: [], created: DateTime.now()),
                          );
                          if (g.id.isEmpty) return const SizedBox.shrink();
                          return IconButton(
                            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.primaryColor),
                            tooltip: 'View group details',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => context.push('/group-detail/${g.id}', extra: g),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              
              // Settlement Plan breakdown with Mobile-Optimized Rows (Showing only your debts)
              Builder(builder: (context) {
                final myDebts = activeSimplifiedDebts.where((d) => isMe(d.debtor) || isMe(d.creditor)).toList();
                if (myDebts.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.swap_horiz, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          _selectedGroupFilter != null 
                              ? 'Your Settlement in ${_selectedGroupFilter == "__direct__" ? "Direct" : _selectedGroupFilter}' 
                              : 'Your Settlement Plan', 
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                          children: myDebts.map((debt) {
                            final debtorIsMe = isMe(debt.debtor);
                            final creditorIsMe = isMe(debt.creditor);
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
                                            group: (_selectedGroupFilter != null && _selectedGroupFilter != '__direct__') ? _selectedGroupFilter : null,
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
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              }),

              // Category Filter & Spending Breakdown
              if (scopeExpenses.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (_selectedCategoryFilter != null)
                      TextButton(
                        onPressed: () => setState(() => _selectedCategoryFilter = null),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Clear Filter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total: ${AppConstants.formatCurrency(grandTotalExpenses)}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => ref.read(navigationIndexProvider.notifier).setIndex(2),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Insights',
                                    style: TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppTheme.primaryColor),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Horizontal scrollable Category Chips with amounts
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // "All" Chip
                      Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: FilterChip(
                          selected: _selectedCategoryFilter == null,
                          showCheckmark: false,
                          label: Text(
                            'All (${scopeExpenses.length})',
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
                      // Individual Category Chips that have expenses
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
                              side: BorderSide(
                                color: isSelected ? cat.color : cat.color.withValues(alpha: 0.25),
                              ),
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedCategoryFilter = isSelected ? null : cat.id;
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Category Total Summary Card (shows when a category is selected)
                if (_selectedCategoryFilter != null) ...[
                  Builder(builder: (context) {
                    final activeCat = ExpenseCategory.fromId(_selectedCategoryFilter);
                    final catTotal = categoryTotals[_selectedCategoryFilter] ?? 0.0;
                    final myShareTotal = categoryMyShareTotals[_selectedCategoryFilter] ?? 0.0;
                    final catCount = categoryCounts[_selectedCategoryFilter] ?? 0;

                    return Container(
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: activeCat.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: activeCat.color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: activeCat.color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(activeCat.icon, color: activeCat.color, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${activeCat.name} Total',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppConstants.formatCurrency(catTotal),
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: activeCat.color),
                                ),
                                Text(
                                  'Your share: ${AppConstants.formatCurrency(myShareTotal)} • $catCount expense${catCount == 1 ? '' : 's'}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Clear filter',
                            onPressed: () => setState(() => _selectedCategoryFilter = null),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 14),
                ],
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedCategoryFilter != null 
                        ? '${ExpenseCategory.fromId(_selectedCategoryFilter).name} Expenses' 
                        : 'Recent Activity', 
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${filteredExpenses.length} ${_selectedCategoryFilter != null ? "filtered" : "total"}',
                    style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Expenses List with shimmer skeleton loading & mobile-optimized tiles
              if (expenseState.isLoading)
                const ExpenseListSkeleton()
              else if (filteredExpenses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28.0),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedCategoryFilter != null ? Icons.filter_alt_off_outlined : Icons.receipt_long_outlined, 
                        size: 44, 
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _selectedCategoryFilter != null 
                            ? 'No expenses in this category' 
                            : 'No expenses recorded yet', 
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      if (_selectedCategoryFilter != null)
                        TextButton(
                          onPressed: () => setState(() => _selectedCategoryFilter = null),
                          child: const Text('Show all expenses'),
                        )
                      else
                        const Text('Tap "+ Add Expense" below to create one.', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
                    ],
                  ),
                )
              else ...[
                Builder(builder: (context) {
                  final displayedExpenses = filteredExpenses.take(_visibleActivityCount).toList();
                  final hasMore = filteredExpenses.length > _visibleActivityCount;

                  return Column(
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayedExpenses.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final exp = displayedExpenses[index];
                          final isPayer = isMe(exp.payer);
                          final isSettlement = exp.isSettlement;
                          final category = exp.categoryDetails;
                          
                          // User's own share of this expense
                          double myShare = 0.0;
                          exp.splitOwed.forEach((key, val) {
                            if (isMe(key)) myShare += val;
                          });

                          // Amount lent vs borrowed calculation
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
                                child: Icon(
                                  category.icon, 
                                  color: category.color,
                                  size: 22,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      exp.description, 
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (exp.group.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedGroupFilter = exp.group;
                                          _selectedCategoryFilter = null;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          exp.group,
                                          style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ]
                                ],
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
                                        maxLines: 1,
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 14,
                                        color: AppTheme.secondaryColor,
                                      ),
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 14,
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (hasMore) ...[
                        const SizedBox(height: 14),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _visibleActivityCount += 15;
                              });
                            },
                            icon: const Icon(Icons.expand_more, size: 18),
                            label: Text(
                              'Load More Activities (${filteredExpenses.length - _visibleActivityCount} remaining)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                            ),
                          ),
                        ),
                      ] else if (filteredExpenses.length > 5) ...[
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            'Showing all ${filteredExpenses.length} activities',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ],
                  );
                }),
              ],
              // Bottom padding to avoid FAB overlap on mobile
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
