import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dashboard_screen.dart';
import '../../groups/presentation/groups_screen.dart';
import '../../insights/presentation/insights_screen.dart';
import '../../friends/presentation/friends_screen.dart';

class NavigationIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

final navigationIndexProvider = NotifierProvider<NavigationIndexNotifier, int>(NavigationIndexNotifier.new);

class MainLayout extends ConsumerWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);

    final List<Widget> screens = const [
      DashboardScreen(),
      GroupsScreen(),
      InsightsScreen(),
      FriendsScreen(),
    ];

    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: double.infinity,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: screens[currentIndex],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(navigationIndexProvider.notifier).setIndex(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Friends',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-expense'),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
}
