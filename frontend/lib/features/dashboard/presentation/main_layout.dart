import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.darkSurface,
          border: Border(
            top: BorderSide(color: AppTheme.darkBorder, width: 1.0),
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            ref.read(navigationIndexProvider.notifier).setIndex(index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group_rounded),
              label: 'Groups',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Insights',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Friends',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-expense'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }
}
