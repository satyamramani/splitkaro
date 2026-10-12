import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/user_provider.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/models/expense_category.dart';
import '../../expenses/presentation/expense_detail_sheet.dart';
import '../../expenses/providers/expense_provider.dart';
import '../../groups/providers/group_provider.dart';

enum TimeRangeFilter {
  thisMonth,
  lastMonth,
  last3Months,
  allTime,
}

enum SpendingScope {
  myShare,
  totalSpend,
}

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  TimeRangeFilter _selectedTimeRange = TimeRangeFilter.last3Months;
  SpendingScope _selectedScope = SpendingScope.totalSpend;
  String? _selectedGroupFilter; // null = all groups, '__direct__' = non-group, or group name
  String? _expandedCategoryId; // Category currently expanded to show transactions

  // Specific custom month offset if user picks a specific month (0 = current month, -1 = last month, etc.)
  int _monthOffset = 0;

  DateTime get _now => DateTime.now();

  @override
  Widget build(BuildContext context) {
    final expenseState = ref.watch(expenseProvider);
    final allExpenses = expenseState.expenses.where((e) => !e.isSettlement).toList();
    final groups = ref.watch(userGroupsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final currentUserName = currentUser.name;

    bool isMe(String name) {
      return currentUser.isMe(name);
    }

    // Isolate expenses to ones this user is involved in
    final userExpenses = allExpenses.where((e) {
      return isMe(e.payer) || e.splitOwed.keys.any((person) => isMe(person));
    }).toList();

    // 1. Group filtering
    final List<Expense> groupFilteredExpenses;
    if (_selectedGroupFilter == null) {
      groupFilteredExpenses = userExpenses;
    } else if (_selectedGroupFilter == '__direct__') {
      groupFilteredExpenses = userExpenses.where((e) => e.group.isEmpty).toList();
    } else {
      groupFilteredExpenses = userExpenses.where((e) => e.group == _selectedGroupFilter).toList();
    }

    // 2. Date filtering
    final DateTime now = _now;
    final DateTime currentMonthStart = DateTime(now.year, now.month, 1);
    final DateTime lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final DateTime lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
    final DateTime threeMonthsAgoStart = DateTime(now.year, now.month - 2, 1);

    final List<Expense> periodExpenses;
    String periodTitle = '';

    switch (_selectedTimeRange) {
      case TimeRangeFilter.thisMonth:
        periodExpenses = groupFilteredExpenses.where((e) => e.date.isAfter(currentMonthStart.subtract(const Duration(seconds: 1)))).toList();
        periodTitle = DateFormat('MMMM yyyy').format(now);
        break;
      case TimeRangeFilter.lastMonth:
        periodExpenses = groupFilteredExpenses.where((e) => e.date.isAfter(lastMonthStart.subtract(const Duration(seconds: 1))) && e.date.isBefore(lastMonthEnd.add(const Duration(seconds: 1)))).toList();
        periodTitle = DateFormat('MMMM yyyy').format(lastMonthStart);
        break;
      case TimeRangeFilter.last3Months:
        periodExpenses = groupFilteredExpenses.where((e) => e.date.isAfter(threeMonthsAgoStart.subtract(const Duration(seconds: 1)))).toList();
        periodTitle = 'Last 3 Months (${DateFormat('MMM').format(threeMonthsAgoStart)} - ${DateFormat('MMM yyyy').format(now)})';
        break;
      case TimeRangeFilter.allTime:
        periodExpenses = groupFilteredExpenses;
        periodTitle = 'All Time';
        break;
    }

    // 3. Compute Spending Metrics
    double getExpenseAmount(Expense exp) {
      if (_selectedScope == SpendingScope.totalSpend) {
        return exp.amount;
      } else {
        double myShare = 0.0;
        exp.splitOwed.forEach((person, amount) {
          if (isMe(person)) myShare += amount;
        });
        return myShare;
      }
    }

    double totalSpend = 0.0;
    final Map<String, double> categorySpends = {};
    final Map<String, int> categoryCounts = {};
    final Map<String, List<Expense>> categoryItems = {};

    for (var exp in periodExpenses) {
      final amt = getExpenseAmount(exp);
      if (amt <= 0 && _selectedScope == SpendingScope.myShare) continue;

      final catId = exp.categoryDetails.id;
      totalSpend += amt;
      categorySpends[catId] = (categorySpends[catId] ?? 0.0) + amt;
      categoryCounts[catId] = (categoryCounts[catId] ?? 0) + 1;
      categoryItems.putIfAbsent(catId, () => []).add(exp);
    }

    // Sort categories by highest spend descending
    final sortedCategoryIds = categorySpends.keys.toList()
      ..sort((a, b) => (categorySpends[b] ?? 0.0).compareTo(categorySpends[a] ?? 0.0));

    // Top Category
    final String topCatId = sortedCategoryIds.isNotEmpty ? sortedCategoryIds.first : '';
    final double topCatSpend = topCatId.isNotEmpty ? (categorySpends[topCatId] ?? 0.0) : 0.0;
    final double topCatPct = totalSpend > 0 ? (topCatSpend / totalSpend * 100) : 0.0;
    final topCategory = topCatId.isNotEmpty ? ExpenseCategory.fromId(topCatId) : null;

    // 4. Month-Wise History Comparison for Last 3 Months
    final List<Map<String, dynamic>> monthlyBars = [];
    for (int i = 2; i >= 0; i--) {
      final mDate = DateTime(now.year, now.month - i, 1);
      final mNext = DateTime(now.year, now.month - i + 1, 1);
      final mExpenses = groupFilteredExpenses.where((e) => e.date.isAfter(mDate.subtract(const Duration(seconds: 1))) && e.date.isBefore(mNext)).toList();
      double mTotal = 0.0;
      for (var e in mExpenses) {
        mTotal += getExpenseAmount(e);
      }
      monthlyBars.add({
        'monthName': DateFormat('MMM').format(mDate),
        'fullDate': mDate,
        'amount': mTotal,
        'count': mExpenses.length,
      });
    }

    final double maxMonthlySpend = monthlyBars.fold(0.0, (max, item) {
      final double amt = item['amount'] as double;
      return amt > max ? amt : max;
    });

    // 5. Top 3 individual expenses in period
    final sortedExpensesInPeriod = [...periodExpenses]..sort((a, b) => getExpenseAmount(b).compareTo(getExpenseAmount(a)));
    final top3Expenses = sortedExpensesInPeriod.take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Insights', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(expenseProvider.notifier).refresh();
              ref.read(groupProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(expenseProvider.notifier).refresh();
          await ref.read(groupProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Scope Toggle (Total Spend vs My Share)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkCardElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedScope = SpendingScope.totalSpend),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedScope == SpendingScope.totalSpend ? AppTheme.primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'Total Spend',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _selectedScope == SpendingScope.totalSpend ? FontWeight.bold : FontWeight.w500,
                                color: _selectedScope == SpendingScope.totalSpend ? Colors.white : AppTheme.textSecondaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedScope = SpendingScope.myShare),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedScope == SpendingScope.myShare ? AppTheme.primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'My Share Only',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _selectedScope == SpendingScope.myShare ? FontWeight.bold : FontWeight.w500,
                                color: _selectedScope == SpendingScope.myShare ? Colors.white : AppTheme.textSecondaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Time Range Selector Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildTimeChip('Last 3 Months', TimeRangeFilter.last3Months, Icons.calendar_view_month),
                    const SizedBox(width: 8),
                    _buildTimeChip('This Month', TimeRangeFilter.thisMonth, Icons.today),
                    const SizedBox(width: 8),
                    _buildTimeChip('Last Month', TimeRangeFilter.lastMonth, Icons.history),
                    const SizedBox(width: 8),
                    _buildTimeChip('All Time', TimeRangeFilter.allTime, Icons.all_inclusive),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Group Filter Bar (Optional scope by group)
              if (groups.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _selectedGroupFilter == null,
                        showCheckmark: false,
                        label: const Text('All Groups', style: TextStyle(fontSize: 11.5)),
                        labelStyle: TextStyle(
                          color: _selectedGroupFilter == null ? Colors.white : AppTheme.textSecondaryColor,
                          fontWeight: _selectedGroupFilter == null ? FontWeight.bold : FontWeight.w500,
                        ),
                        selectedColor: AppTheme.primaryColor,
                        backgroundColor: AppTheme.darkCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: _selectedGroupFilter == null ? AppTheme.primaryColor : AppTheme.darkBorder),
                        ),
                        onSelected: (_) => setState(() => _selectedGroupFilter = null),
                      ),
                      const SizedBox(width: 6),
                      ...groups.map((g) => Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: FilterChip(
                              selected: _selectedGroupFilter == g.name,
                              showCheckmark: false,
                              avatar: Icon(Icons.group_outlined, size: 13, color: _selectedGroupFilter == g.name ? Colors.white : AppTheme.primaryLight),
                              label: Text(g.name, style: const TextStyle(fontSize: 11.5)),
                              labelStyle: TextStyle(
                                color: _selectedGroupFilter == g.name ? Colors.white : AppTheme.textSecondaryColor,
                                fontWeight: _selectedGroupFilter == g.name ? FontWeight.bold : FontWeight.w500,
                              ),
                              selectedColor: AppTheme.primaryColor,
                              backgroundColor: AppTheme.darkCard,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: _selectedGroupFilter == g.name ? AppTheme.primaryColor : AppTheme.darkBorder),
                              ),
                              onSelected: (_) => setState(() => _selectedGroupFilter = _selectedGroupFilter == g.name ? null : g.name),
                            ),
                          )),
                      FilterChip(
                        selected: _selectedGroupFilter == '__direct__',
                        showCheckmark: false,
                        avatar: Icon(Icons.person_pin_circle_outlined, size: 13, color: _selectedGroupFilter == '__direct__' ? Colors.white : AppTheme.secondaryColor),
                        label: const Text('Direct / Non-Group', style: TextStyle(fontSize: 11.5)),
                        labelStyle: TextStyle(
                          color: _selectedGroupFilter == '__direct__' ? Colors.white : AppTheme.textSecondaryColor,
                          fontWeight: _selectedGroupFilter == '__direct__' ? FontWeight.bold : FontWeight.w500,
                        ),
                        selectedColor: AppTheme.secondaryColor.withValues(alpha: 0.8),
                        backgroundColor: AppTheme.darkCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: _selectedGroupFilter == '__direct__' ? AppTheme.secondaryColor : AppTheme.darkBorder),
                        ),
                        onSelected: (_) => setState(() => _selectedGroupFilter = _selectedGroupFilter == '__direct__' ? null : '__direct__'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Big Summary Card
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedScope == SpendingScope.totalSpend ? 'TOTAL SPENDING' : 'YOUR SHARE OF SPEND',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            periodTitle,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppConstants.formatCurrency(totalSpend),
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Top Category',
                                  style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8)),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  topCategory != null ? topCategory.name : 'None',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (topCatPct > 0)
                                  Text(
                                    '${topCatPct.toStringAsFixed(0)}% of total',
                                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Expenses Count',
                                  style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8)),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${periodExpenses.length} transactions',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                Text(
                                  'Avg ${periodExpenses.isNotEmpty ? AppConstants.formatCurrency(totalSpend / periodExpenses.length) : "₹0"}/exp',
                                  style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Month-Wise Comparison Bar Chart (Last 3 Months Trend)
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
                    const Row(
                      children: [
                        Icon(Icons.bar_chart_rounded, color: AppTheme.primaryColor, size: 20),
                        SizedBox(width: 8),
                        Text('Month-Wise Trend (Last 3 Months)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: monthlyBars.map((m) {
                        final double amt = m['amount'] as double;
                        final String monthName = m['monthName'] as String;
                        final double ratio = maxMonthlySpend > 0 ? (amt / maxMonthlySpend) : 0.0;
                        final bool isHighlighted = _selectedTimeRange == TimeRangeFilter.last3Months ||
                            (_selectedTimeRange == TimeRangeFilter.thisMonth && monthName == DateFormat('MMM').format(now));

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Column(
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    AppConstants.formatCurrency(amt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: amt > 0 ? AppTheme.textPrimaryColor : AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  height: 110,
                                  width: double.infinity,
                                  alignment: Alignment.bottomCenter,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOutCubic,
                                    height: ratio * 100 > 8 ? ratio * 100 : (amt > 0 ? 8 : 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: isHighlighted
                                            ? [AppTheme.primaryColor, const Color(0xFF818CF8)]
                                            : [AppTheme.darkCardElevated, AppTheme.darkBorder],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  monthName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                                    color: isHighlighted ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Category-Wise Spending Breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Category Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    '${sortedCategoryIds.length} categories',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (sortedCategoryIds.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28.0),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.pie_chart_outline, size: 40, color: AppTheme.textSecondaryColor),
                      SizedBox(height: 8),
                      Text('No expenses recorded for this period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 4),
                      Text('Try selecting "Last 3 Months" or "All Time" to view your historical spending.',
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
                    ],
                  ),
                )
              else
                ...sortedCategoryIds.map((catId) {
                  final cat = ExpenseCategory.fromId(catId);
                  final double catSpend = categorySpends[catId] ?? 0.0;
                  final int catCount = categoryCounts[catId] ?? 0;
                  final double pct = totalSpend > 0 ? (catSpend / totalSpend) : 0.0;
                  final bool isExpanded = _expandedCategoryId == catId;
                  final List<Expense> items = categoryItems[catId] ?? [];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Card(
                      elevation: 0,
                      color: AppTheme.darkCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isExpanded ? cat.color.withValues(alpha: 0.5) : AppTheme.darkBorder,
                          width: isExpanded ? 1.5 : 1.0,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _expandedCategoryId = isExpanded ? null : catId;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: cat.color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(cat.icon, color: cat.color, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$catCount expense${catCount == 1 ? '' : 's'} • ${(pct * 100).toStringAsFixed(1)}% of total',
                                          style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        AppConstants.formatCurrency(catSpend),
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cat.color),
                                      ),
                                      Icon(
                                        isExpanded ? Icons.expand_less : Icons.expand_more,
                                        size: 16,
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Smooth Progress Bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 6,
                                  backgroundColor: AppTheme.darkCardElevated,
                                  valueColor: AlwaysStoppedAnimation<Color>(cat.color),
                                ),
                              ),

                              // Expanded List of transactions for this category
                              if (isExpanded) ...[
                                const Divider(height: 20),
                                ...items.map((item) {
                                  final double itemAmt = getExpenseAmount(item);
                                  return InkWell(
                                    onTap: () => ExpenseDetailSheet.show(context, item),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 4.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.description,
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '${DateFormat('MMM d').format(item.date)} • Paid by ${item.payer}${item.group.isNotEmpty ? " • ${item.group}" : ""}',
                                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            AppConstants.formatCurrency(itemAmt),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 20),

              // Top Spends in Selected Period
              if (top3Expenses.isNotEmpty) ...[
                const Text('Largest Expenses in Period', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
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
                      children: top3Expenses.map((exp) {
                        final double amt = getExpenseAmount(exp);
                        final cat = exp.categoryDetails;

                        return InkWell(
                          onTap: () => ExpenseDetailSheet.show(context, exp),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: cat.color.withValues(alpha: 0.15),
                                  child: Icon(cat.icon, color: cat.color, size: 14),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exp.description,
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${DateFormat('MMM d').format(exp.date)} • ${cat.name}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  AppConstants.formatCurrency(amt),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeChip(String label, TimeRangeFilter filter, IconData icon) {
    final isSelected = _selectedTimeRange == filter;
    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : AppTheme.primaryLight),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : AppTheme.textSecondaryColor,
      ),
      selectedColor: AppTheme.primaryColor,
      backgroundColor: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? AppTheme.primaryColor : AppTheme.darkBorder),
      ),
      onSelected: (_) => setState(() => _selectedTimeRange = filter),
    );
  }
}
