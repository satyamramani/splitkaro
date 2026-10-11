import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/user_provider.dart';
import '../../expenses/presentation/settle_up_sheet.dart';
import '../../expenses/providers/expense_provider.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  Future<void> _showAddFriendDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Friend', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Friend\'s name',
            hintText: 'e.g. Charlie',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = nameController.text.trim();
              if (text.isNotEmpty) Navigator.pop(ctx, text);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final newUser = await ref.read(usersProvider.notifier).addUser(name);
      if (context.mounted && newUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${newUser.name} to friends!'), backgroundColor: AppTheme.secondaryColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersState = ref.watch(usersProvider);
    final currentUser = ref.watch(currentUserProvider);
    final currentUserName = currentUser.name;
    final debts = ref.watch(simplifiedDebtsProvider);

    bool isMe(String name) {
      final n = name.trim().toLowerCase();
      return n == currentUserName.toLowerCase() || n == 'you' || n == 'satyam';
    }

    final friends = usersState.users.where((u) => !isMe(u.name)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Friend',
            onPressed: () => _showAddFriendDialog(context, ref),
          )
        ],
      ),
      body: usersState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : friends.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 64, color: AppTheme.textSecondaryColor),
                      const SizedBox(height: 16),
                      const Text('No friends added yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddFriendDialog(context, ref),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add your first friend'),
                      )
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: friends.length + 1, // +1 for bottom FAB spacing
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == friends.length) {
                      return const SizedBox(height: 80); // FAB safe padding
                    }

                    final friend = friends[index];
                    
                    // Calculate net balance between currentUser and this friend
                    double balance = 0.0;
                    for (var d in debts) {
                      final isMeDebtor = isMe(d.debtor);
                      final isMeCreditor = isMe(d.creditor);
                      final isFriendDebtor = d.debtor == friend.name;
                      final isFriendCreditor = d.creditor == friend.name;

                      if (isMeCreditor && isFriendDebtor) {
                        balance += d.amount; // Friend owes you
                      } else if (isMeDebtor && isFriendCreditor) {
                        balance -= d.amount; // You owe friend
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                            foregroundColor: AppTheme.primaryColor,
                            child: Text(
                              friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  friend.name, 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  friend.email.isNotEmpty ? friend.email : 'Friend', 
                                  style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (balance > 0.01) ...[
                                const Text('owes you', style: TextStyle(fontSize: 11, color: AppTheme.secondaryColor)),
                                Text(
                                  '+${AppConstants.formatCurrency(balance)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor, fontSize: 14.5),
                                ),
                              ] else if (balance < -0.01) ...[
                                const Text('you owe', style: TextStyle(fontSize: 11, color: AppTheme.errorColor)),
                                Text(
                                  '-${AppConstants.formatCurrency(balance.abs())}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorColor, fontSize: 14.5),
                                ),
                              ] else ...[
                                const Text('settled up', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
                              ],
                              if (balance.abs() > 0.01) ...[
                                const SizedBox(height: 3),
                                InkWell(
                                  onTap: () {
                                    SettleUpSheet.show(
                                      context,
                                      debtor: balance > 0 ? friend.name : currentUserName,
                                      creditor: balance > 0 ? currentUserName : friend.name,
                                      defaultAmount: balance.abs(),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Settle',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
