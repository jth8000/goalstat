import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goalstat/data/database.dart';
import 'package:goalstat/screens/settings_screen.dart';
import 'package:goalstat/screens/today_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late Database _db;

/// Pumps [screen] and lets its real (non-fake-async) database loads finish.
Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(home: screen));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pumpAndSettle();
}

/// Lets database writes triggered by a tap finish, then settles the UI.
Future<void> _settleDb(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String current, String option) async {
  await tester.tap(find.text(current));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  sqfliteFfiInit();

  setUp(() async {
    _db = await AppDatabase.openAt(inMemoryDatabasePath, factory: databaseFactoryFfi);
    AppDatabase.useForTesting(_db);
  });

  tearDown(() => _db.close());

  group('goal dialog', () {
    testWidgets('daily yes/no shows Do/Avoid instead of Direction and Target',
        (tester) async {
      await _pump(tester, SettingsScreen(onGoalsChanged: () {}));
      await tester.tap(find.text('Add Goal'));
      await tester.pumpAndSettle();

      expect(find.text('Goal'), findsOneWidget);
      expect(find.text('Direction'), findsNothing);
      expect(find.text('Target'), findsNothing);

      await _choose(tester, 'Daily', 'Weekly');
      expect(find.text('Goal'), findsNothing);
      expect(find.text('Direction'), findsOneWidget);
      expect(find.text('Target (total per week)'), findsOneWidget);
    });

    testWidgets('an Avoid goal is saved as at most 0', (tester) async {
      await _pump(tester, SettingsScreen(onGoalsChanged: () {}));
      await tester.tap(find.text('Add Goal'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Smoking');
      await _choose(tester, 'Do it  (yes = on target)', 'Avoid it  (no = on target)');
      await tester.tap(find.text('Add'));
      await _settleDb(tester);

      final saved = (await tester.runAsync(() => AppDatabase.instance.getGoals()))!
          .singleWhere((g) => g.name == 'Smoking');
      expect(saved.targetDirection, 'lte');
      expect(saved.targetValue, 0);
      // The list refreshed with the new goal (7th tile, below the fold).
      await tester.scrollUntilVisible(find.textContaining('Avoid it'), 200);
      expect(find.textContaining('Avoid it'), findsOneWidget);
    });
  });

  group('Today', () {
    testWidgets("can't move past today", (tester) async {
      await _pump(tester, TodayScreen(onSaved: () {}));
      IconButton button(String tooltip) => tester.widget<IconButton>(
          find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton)));

      expect(button('Next day').onPressed, isNull);
      await tester.tap(find.byTooltip('Previous day'));
      await _settleDb(tester);
      expect(find.text('Check-in'), findsOneWidget);
      expect(button('Next day').onPressed, isNotNull);
    });
  });

  group('empty states', () {
    setUp(() async => _db.delete('goals'));

    testWidgets('Today', (tester) async {
      await _pump(tester, TodayScreen(onSaved: () {}));
      expect(find.text('No goals yet. Add one in Settings.'), findsOneWidget);
    });

    testWidgets('Settings', (tester) async {
      await _pump(tester, SettingsScreen(onGoalsChanged: () {}));
      expect(find.text('No goals yet. Tap + to add one.'), findsOneWidget);
    });
  });
}
