import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/user_provider.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/group_provider.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../providers/expense_provider.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String? initialGroupName;
  final Expense? existingExpense;

  const AddExpenseScreen({
    super.key, 
    this.initialGroupName,
    this.existingExpense,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  
  String _splitMethod = 'Equally';
  final List<String> _splitMethods = ['Equally', 'Exact', 'Percentages'];
  
  String? _payerName;
  String? _selectedGroupName;
  ExpenseCategory _selectedCategory = ExpenseCategory.general;
  bool _manuallySelectedCategory = false;
  
  final Set<String> _selectedParticipants = {};
  final Map<String, TextEditingController> _customControllers = {};

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_onDescriptionChanged);

    if (widget.existingExpense != null) {
      final exp = widget.existingExpense!;
      _descriptionController.text = exp.description;
      _amountController.text = exp.amount.toStringAsFixed(2);
      _payerName = exp.payer;
      _selectedGroupName = exp.group.isNotEmpty ? exp.group : null;
      _selectedCategory = exp.categoryDetails;
      _manuallySelectedCategory = true;
      _selectedParticipants.addAll(exp.splitOwed.keys);

      // Inspect if splits were exact or custom
      final count = exp.splitOwed.length;
      if (count > 0) {
        final equalShare = exp.amount / count;
        bool allEqual = true;
        exp.splitOwed.forEach((_, val) {
          if ((val - equalShare).abs() > 0.05) {
            allEqual = false;
          }
        });
        if (!allEqual) {
          _splitMethod = 'Exact';
        }
      }

      exp.splitOwed.forEach((person, val) {
        _customControllers[person] = TextEditingController(text: val.toStringAsFixed(2));
      });
    } else if (widget.initialGroupName != null) {
      _selectedGroupName = widget.initialGroupName;
    }
  }

  void _onDescriptionChanged() {
    if (!_manuallySelectedCategory) {
      final suggested = ExpenseCategory.suggestFromDescription(_descriptionController.text);
      if (suggested != _selectedCategory) {
        setState(() {
          _selectedCategory = suggested;
        });
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    _amountController.dispose();
    for (var c in _customControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncParticipants(List<String> userNames, String currentUserName, List<Group> groups) {
    if (_payerName == null || !userNames.contains(_payerName)) {
      _payerName = userNames.contains(currentUserName) ? currentUserName : (userNames.isNotEmpty ? userNames.first : 'You');
    }
    if (_selectedParticipants.isEmpty) {
      if (_selectedGroupName != null) {
        final matching = groups.where((g) => g.name == _selectedGroupName).toList();
        if (matching.isNotEmpty) {
          _selectedParticipants.addAll(matching.first.members);
        } else {
          _selectedParticipants.addAll(userNames);
        }
      } else {
        _selectedParticipants.addAll(userNames);
      }
    }
    for (var name in userNames) {
      if (!_customControllers.containsKey(name)) {
        _customControllers[name] = TextEditingController();
      }
    }
  }

  Future<void> _promptAddPerson() async {
    final textController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a Friend', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Friend\'s name',
            hintText: 'e.g. Charlie',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = textController.text.trim();
              if (val.isNotEmpty) Navigator.of(ctx).pop(val);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final newUser = await ref.read(usersProvider.notifier).addUser(name);
      if (newUser != null) {
        setState(() {
          _selectedParticipants.add(newUser.name);
          _customControllers[newUser.name] = TextEditingController();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added ${newUser.name}!'), backgroundColor: AppTheme.secondaryColor),
          );
        }
      }
    }
  }

  Future<void> _saveExpense() async {
    final rawDesc = _descriptionController.text.trim();
    final desc = rawDesc.isEmpty ? 'General' : rawDesc;
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.'), backgroundColor: AppTheme.errorColor),
      );
      return;
    }

    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one person to split with.'), backgroundColor: AppTheme.errorColor),
      );
      return;
    }

    final payer = _payerName ?? 'You';
    final Map<String, double> splits = {};

    if (_splitMethod == 'Equally') {
      final splitAmount = amount / _selectedParticipants.length;
      for (var person in _selectedParticipants) {
        splits[person] = splitAmount;
      }
    } else if (_splitMethod == 'Exact') {
      double totalEntered = 0;
      for (var person in _selectedParticipants) {
        final val = double.tryParse(_customControllers[person]?.text ?? '') ?? 0.0;
        splits[person] = val;
        totalEntered += val;
      }
      if ((totalEntered - amount).abs() > 0.05) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exact amounts (${AppConstants.formatCurrency(totalEntered)}) must equal total (${AppConstants.formatCurrency(amount)}).'), 
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
    } else if (_splitMethod == 'Percentages') {
      double totalPercent = 0;
      for (var person in _selectedParticipants) {
        final pct = double.tryParse(_customControllers[person]?.text ?? '') ?? 0.0;
        splits[person] = (amount * pct) / 100.0;
        totalPercent += pct;
      }
      if ((totalPercent - 100.0).abs() > 0.5) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Percentages (${totalPercent.toStringAsFixed(1)}%) must add up to 100%.'), 
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
    }

    final isEditing = widget.existingExpense != null;

    if (isEditing) {
      final updatedExpense = Expense(
        id: widget.existingExpense!.id,
        description: desc,
        amount: amount,
        payer: payer,
        splitOwed: splits,
        group: _selectedGroupName ?? '',
        category: _selectedCategory.id,
        date: widget.existingExpense!.date,
      );

      final success = await ref.read(expenseProvider.notifier).updateExpense(updatedExpense);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense updated successfully!'), backgroundColor: AppTheme.secondaryColor),
        );
        context.pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update expense in PocketBase.'), backgroundColor: AppTheme.errorColor),
        );
      }
    } else {
      final newExpense = Expense(
        id: '',
        description: desc,
        amount: amount,
        payer: payer,
        splitOwed: splits,
        group: _selectedGroupName ?? '',
        category: _selectedCategory.id,
        date: DateTime.now(),
      );

      final success = await ref.read(expenseProvider.notifier).addExpense(newExpense);
      if (success && mounted) {
        context.pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save expense to PocketBase.'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    if (widget.existingExpense == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Are you sure you want to delete "${widget.existingExpense!.description}"?'),
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

    if (confirmed == true && mounted) {
      await ref.read(expenseProvider.notifier).deleteExpense(widget.existingExpense!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted successfully'), backgroundColor: AppTheme.secondaryColor),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(usersProvider);
    final groupState = ref.watch(groupProvider);
    final currentUser = ref.watch(currentUserProvider);
    final currentUserName = currentUser.name;

    final userList = usersState.users;
    final userNames = userList.map((u) => u.name).toList();
    if (!userNames.contains(currentUserName)) {
      userNames.insert(0, currentUserName);
    }

    _syncParticipants(userNames, currentUserName, groupState.groups);

    final isEditing = widget.existingExpense != null;
    final titleText = isEditing
        ? 'Edit Expense'
        : (_selectedGroupName != null && _selectedGroupName!.isNotEmpty 
            ? 'Add to $_selectedGroupName' 
            : 'Add an expense');

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
              tooltip: 'Delete Expense',
              onPressed: _confirmDelete,
            ),
          IconButton(
            icon: const Icon(Icons.check, color: AppTheme.primaryColor),
            tooltip: isEditing ? 'Update Expense' : 'Save Expense',
            onPressed: _saveExpense,
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
            onPressed: _saveExpense,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: Icon(isEditing ? Icons.save_outlined : Icons.check_circle_outline, size: 20),
            label: Text(
              isEditing ? 'Update Expense' : 'Save Expense', 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Description & Animated Category Avatar Input
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _selectedCategory.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _selectedCategory.color.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      _selectedCategory.icon,
                      key: ValueKey(_selectedCategory.id),
                      color: _selectedCategory.color,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      hintText: 'Enter a description (optional)',
                      hintStyle: TextStyle(fontSize: 16, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.normal),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                    ),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Amount field with Rupee symbol (Mobile Responsive)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  AppConstants.currencySymbol, 
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Horizontal Category Selector Chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: ExpenseCategory.allCategories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final cat = ExpenseCategory.allCategories[index];
                  final isSelected = _selectedCategory.id == cat.id;

                  return FilterChip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(cat.icon, size: 15, color: isSelected ? Colors.white : cat.color),
                    label: Text(
                      cat.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
                      ),
                    ),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: cat.color,
                    backgroundColor: cat.color.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isSelected ? cat.color : Colors.transparent),
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedCategory = cat;
                        _manuallySelectedCategory = true;
                      });
                    },
                  );
                },
              ),
            ),
            const Divider(height: 28),
            
            // Clean, Overflow-Proof Mobile Controls (Paid by & Group)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Paid by', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryColor)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AppTheme.surfaceColor,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            isDense: true,
                            value: _payerName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                            items: userNames.map((name) {
                              final isYou = name == currentUserName;
                              return DropdownMenuItem(
                                value: name, 
                                child: Text(
                                  isYou ? '$name (You)' : name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _payerName = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (groupState.groups.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryColor)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: AppTheme.surfaceColor,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              isDense: true,
                              value: _selectedGroupName,
                              hint: const Text('Direct split', style: TextStyle(fontSize: 12)),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Direct split', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13)),
                                ),
                                ...groupState.groups.map((g) => DropdownMenuItem<String?>(
                                  value: g.name,
                                  child: Text(g.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                )),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedGroupName = val;
                                  if (val != null) {
                                    final group = groupState.groups.firstWhere((g) => g.name == val);
                                    _selectedParticipants.clear();
                                    _selectedParticipants.addAll(group.members);
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Split method Segmented Button (Compact text for mobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Split method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryColor)),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: _splitMethods.map((m) {
                      final label = m == 'Percentages' ? 'Percent' : m;
                      return ButtonSegment(
                        value: m, 
                        label: Text(label, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    selected: {_splitMethod},
                    onSelectionChanged: (set) {
                      setState(() => _splitMethod = set.first);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppTheme.primaryColor.withValues(alpha: 0.12);
                        }
                        return Colors.transparent;
                      }),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Split Details Header + Add Person button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Split with', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _promptAddPerson,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: const Text('Add person', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Participant rows (Mobile Optimized)
            ...userNames.map((person) {
              final isSelected = _selectedParticipants.contains(person);
              final isYou = person == currentUserName;
              final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
              final splitEach = _selectedParticipants.isNotEmpty ? (totalAmount / _selectedParticipants.length) : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.surfaceColor : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.3) : Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      visualDensity: VisualDensity.compact,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedParticipants.add(person);
                          } else {
                            if (_selectedParticipants.length > 1) {
                              _selectedParticipants.remove(person);
                            }
                          }
                        });
                      },
                    ),
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: isYou ? AppTheme.primaryColor : AppTheme.secondaryColor, 
                      foregroundColor: Colors.white,
                      child: Text(person.isNotEmpty ? person[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isYou ? '$person (You)' : person, 
                            style: TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.w600,
                              color: isSelected ? AppTheme.textPrimaryColor : AppTheme.textSecondaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          if (_payerName == person)
                            const Text('Payer', style: TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isSelected)
                      const Text('Excluded', style: TextStyle(color: AppTheme.textSecondaryColor, fontStyle: FontStyle.italic, fontSize: 12))
                    else if (_splitMethod == 'Equally')
                      Text(
                        AppConstants.formatCurrency(splitEach), 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                      )
                    else if (_splitMethod == 'Percentages')
                      SizedBox(
                        width: 70,
                        child: TextField(
                          controller: _customControllers[person],
                          decoration: const InputDecoration(
                            suffixText: '%',
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 14),
                        ),
                      )
                    else 
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _customControllers[person],
                          decoration: const InputDecoration(
                            prefixText: AppConstants.currencySymbol,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
