import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noctra/core/utils/noctra_localization.dart';
import 'package:noctra/main.dart';
import 'package:noctra/data/repositories/music_repository.dart';
import 'package:noctra/providers/app_providers.dart';
import 'package:noctra/ui/screens/onboarding/onboarding_screen.dart';
import 'package:noctra/ui/screens/settings_sheet.dart';
import 'package:noctra/ui/widgets/noir_sidebar.dart';

void main() {
  setUp(() => MusicRepository.debugResetSingleton());
  testWidgets('Noctra App Onboarding Initial Render Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appInitializedProvider.overrideWith((ref) => true),
        ],
        child: const NoctraApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Onboarding Screen Step Progression Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NOCTRA'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('Hindi'), findsOneWidget);

    await tester.tap(find.text('Hindi'));
    await tester.pumpAndSettle();

    final nextButton = find.text('Next');
    expect(nextButton, findsOneWidget);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('Bollywood'), findsOneWidget);
  });

  testWidgets('NoirSidebar Navigation and Localization Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            drawer: NoirSidebar(),
            body: Center(child: Text('Main Body')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    expect(find.text(NoctraLocalization.tr('app_name')), findsWidgets);
    expect(find.text(NoctraLocalization.tr('search_explore')), findsOneWidget);
    expect(find.text(NoctraLocalization.tr('library_title')), findsOneWidget);
  });

  testWidgets('SettingsSheet Theme and Language Selection Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SettingsSheet(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(NoctraLocalization.tr('settings')), findsOneWidget);
    // Theme chips: Noir Black, Noir White, Liquid Glass
    expect(find.text('Noir Black'), findsAtLeastNWidgets(1));
    expect(find.text('Noir White'), findsAtLeastNWidgets(1));
    expect(find.text('Liquid Glass'), findsAtLeastNWidgets(1));
    expect(find.text('Language / भाषा'), findsOneWidget);
  });

  testWidgets('App icon change shows confirmation popup dialog', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SettingsSheet(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on 'Noir Black' icon chip
    final iconChips = find.text('Noir Black');
    expect(iconChips, findsAtLeastNWidgets(1));
    // The second 'Noir Black' is the icon chip in ThemeAndIconSection
    await tester.tap(iconChips.last);
    await tester.pumpAndSettle();

    // Verify confirmation dialog appears
    expect(find.text('Change App Icon'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
    expect(find.text('Yes, Apply'), findsOneWidget);

    // Tap 'No' to dismiss
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(find.text('Change App Icon'), findsNothing);
  });
}
