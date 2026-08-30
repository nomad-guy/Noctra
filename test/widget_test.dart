import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noctra/main.dart';
import 'package:noctra/providers/app_providers.dart';

void main() {
  testWidgets('Noctra app loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appInitializedProvider.overrideWith((ref) => true),
        ],
        child: const NoctraApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('NOCTRA'), findsWidgets);
  });
}
