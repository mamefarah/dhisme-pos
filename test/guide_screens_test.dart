import 'package:dhisme_pos/core/i18n/app_language.dart';
import 'package:dhisme_pos/features/auth/models/app_profile.dart';
import 'package:dhisme_pos/features/guides/data/workflow_guides.dart';
import 'package:dhisme_pos/features/guides/screens/guide_viewer_screen.dart';
import 'package:dhisme_pos/features/guides/screens/guides_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppProfile _profile(String role) => AppProfile(id: 'u', storeId: 's', fullName: 'Test', role: role);

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguage.instance.setLanguage('en');
  });

  testWidgets('seller list hides purchase guide', (tester) async {
    await _pump(tester, GuidesScreen(profile: _profile('seller')));
    expect(find.text('Sell an item'), findsOneWidget);
    expect(find.text('Sell on credit'), findsOneWidget);
    expect(find.text('Buy and replenish stock'), findsNothing);
  });

  testWidgets('manager list shows all four guides', (tester) async {
    await _pump(tester, GuidesScreen(profile: _profile('manager')));
    expect(find.text('Buy and replenish stock'), findsOneWidget);
    expect(find.text('Returns and cash closing'), findsOneWidget);
  });

  testWidgets('list switches to Somali', (tester) async {
    await AppLanguage.instance.setLanguage('so');
    await _pump(tester, GuidesScreen(profile: _profile('owner')));
    expect(find.text('Sida loo iibiyo alaab'), findsOneWidget);
    expect(find.text('Sell an item'), findsNothing);
  });

  testWidgets('tapping a guide opens it and Back/Next walk the stages in order', (tester) async {
    await _pump(tester, GuidesScreen(profile: _profile('seller')));
    await tester.tap(find.text('Sell an item'));
    await tester.pumpAndSettle();

    final titles = workflowGuides.first.sequences.single.steps.map((s) => s.title.en).toList();
    expect(find.text(titles.first), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Back')).onPressed, isNull);

    for (var i = 1; i < titles.length; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text(titles[i]), findsOneWidget);
    }
    expect(find.text('Next'), findsNothing);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text(titles[titles.length - 2]), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(GuideViewerScreen), findsNothing);
    expect(find.byType(GuidesScreen), findsOneWidget);
  });

  testWidgets('combined guide offers a switch between returns and closing for managers only', (tester) async {
    final guide = workflowGuides.firstWhere((g) => g.id == 'returns_closing');
    await _pump(tester, GuideViewerScreen(key: const ValueKey('m'), guide: guide, role: 'manager'));
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
    expect(find.text('Open the sale receipt'), findsOneWidget);
    await tester.tap(find.text('Cash closing'));
    await tester.pumpAndSettle();
    expect(find.text('Count the cash'), findsOneWidget);

    await _pump(tester, GuideViewerScreen(key: const ValueKey('s'), guide: guide, role: 'seller'));
    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(find.text('Count the cash'), findsOneWidget);
  });

  testWidgets('buttons meet the 48dp tap target and nothing overflows at 360dp in Somali', (tester) async {
    await AppLanguage.instance.setLanguage('so');
    await _pump(tester, GuideViewerScreen(guide: workflowGuides.firstWhere((g) => g.id == 'purchase'), role: 'owner'));
    for (var i = 0; i < 5; i++) {
      expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
      if (i < 4) {
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
      }
    }
  });
}
