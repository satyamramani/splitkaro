import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitwise_clone/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SplitwiseCloneApp()));
    expect(find.byType(SplitwiseCloneApp), findsOneWidget);
  });
}
