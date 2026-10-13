import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/expense.dart';

class ExpenseActivityCard extends StatelessWidget {
  final Expense expense;
  final bool Function(String) isMe;
  final VoidCallback? onTap;
  final Future<bool> Function()? confirmDismiss;
  final VoidCallback? onDismissed;
  final void Function(String)? onGroupTap;
  final bool showGroupBadge;

  const ExpenseActivityCard({
    super.key,
    required this.expense,
    required this.isMe,
    this.onTap,
    this.confirmDismiss,
    this.onDismissed,
    this.onGroupTap,
    this.showGroupBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final isPayer = isMe(expense.payer);
    final isSettlement = expense.isSettlement;
    final category = expense.categoryDetails;

    // User's own share of this expense
    double myShare = 0.0;
    expense.splitOwed.forEach((key, val) {
      if (isMe(key)) myShare += val;
    });

    final double youLent = isPayer ? (expense.amount - myShare) : 0.0;
    final double youBorrowed = !isPayer ? myShare : 0.0;
    final bool notInvolved = !isPayer && myShare == 0.0;

    final cardContent = Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 15.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Category icon with vibrant rounded tile
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: category.color.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    category.icon,
                    color: category.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),

                // Center Column: Title, Group Tag, Meta row
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Row: Title + Group Tag
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              expense.description,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15.5,
                                color: AppTheme.textPrimaryColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (showGroupBadge && expense.group.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: onGroupTap != null ? () => onGroupTap!(expense.group) : null,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.group_outlined, size: 11, color: AppTheme.primaryColor),
                                    const SizedBox(width: 3.5),
                                    Text(
                                      expense.group,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Meta Row: Category Badge • Date • Payer
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: category.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              category.name,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: category.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${DateFormat('MMM d').format(expense.date)} • ${isPayer ? "You" : expense.payer} paid ${AppConstants.formatCurrency(expense.amount)}',
                              style: const TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Right Column: Personal impact amount & Status badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSettlement) ...[
                      Text(
                        AppConstants.formatCurrency(expense.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, size: 10.5, color: AppTheme.secondaryColor),
                            SizedBox(width: 3),
                            Text(
                              'Settled',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isPayer && youLent > 0.01) ...[
                      Text(
                        '+${AppConstants.formatCurrency(youLent)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'you lent',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                      ),
                    ] else if (notInvolved) ...[
                      Text(
                        AppConstants.formatCurrency(expense.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBorder.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'not involved',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        '-${AppConstants.formatCurrency(youBorrowed)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.errorColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'you borrowed',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmDismiss != null && onDismissed != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Dismissible(
          key: Key(expense.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppTheme.errorColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
          ),
          confirmDismiss: (_) => confirmDismiss!(),
          onDismissed: (_) => onDismissed!(),
          child: cardContent,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: cardContent,
    );
  }
}
