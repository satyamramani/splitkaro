import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/pocketbase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final pocketBase = await initPocketBase();

  runApp(
    ProviderScope(
      overrides: [
        pocketBaseProvider.overrideWithValue(pocketBase),
      ],
      child: const SplitwiseCloneApp(),
    ),
  );
}

class SplitwiseCloneApp extends ConsumerWidget {
  const SplitwiseCloneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Expense Splitter',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
