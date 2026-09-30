import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goalstat/data/database.dart';
import 'package:goalstat/models/goal.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late Database _db;
AppDatabase get _app => AppDatabase.instance;

Future<Goal> _goal(String evalPeriod, String type, String direction,
    double target) async {
  final g = Goal(
    name: '$evalPeriod $type $direction $target',
    category: '',
    type: type,
    evalPeriod: evalPeriod,
    targetValue: target,
    targetDirection: direction,
  );
  final id = await _app.addGoal(g);
  return g.copyWith(id: id);
}

Future<void> _log(Goal g, String date, double value) =>
    _app.saveEntry(g.id!, date, value);

Future<void> _logAll(Goal g, List<String> dates, [double value = 1]) async {
  for (final d in dates) {
    await _log(g, d, value);
  }
}

void main() {
  sqfliteFfiInit();

  setUp(() async {
    _db = await AppDatabase.openAt(inMemoryDatabasePath, factory: databaseFactoryFfi);
    AppDatabase.useForTesting(_db);
    // Wednesday; weeks run Mon 28 Sep – Sun 4 Oct.
    AppDatabase.clock = () => DateTime(2026, 9, 30, 12);
    Goal.firstWeekday = DateTime.monday;
  });

  tearDown(() async {
    await _db.close();
    AppDatabase.clock = DateTime.now;
  });

  group('daily streak', () {
    late Goal g;
    setUp(() async => g = await _goal('daily', 'boolean', 'gte', 1));

    test('counts consecutive hits; today unlogged does not break it', () async {
      await _logAll(g, ['2026-09-27', '2026-09-28', '2026-09-29']);
      expect(await _app.getStreak(g), 3);
    });

    test('today counts once hit', () async {
      await _logAll(g, ['2026-09-28', '2026-09-29', '2026-09-30']);
      expect(await _app.getStreak(g), 3);
    });

    test('a miss logged today does not break it until the day is over', () async {
      await _logAll(g, ['2026-09-28', '2026-09-29']);
      await _log(g, '2026-09-30', 0);
      expect(await _app.getStreak(g), 2);
    });

    test('a missed or unlogged day breaks it', () async {
      await _logAll(g, ['2026-09-26', '2026-09-29']);
      await _log(g, '2026-09-27', 0);
      expect(await _app.getStreak(g), 1);
    });
  });

  group('weekly streak', () {
    test('an undecided current week is ignored; a hit week counts', () async {
      final g = await _goal('weekly', 'boolean', 'gte', 3);
      await _logAll(g, ['2026-09-14', '2026-09-15', '2026-09-16']);
      await _logAll(g, ['2026-09-21', '2026-09-22', '2026-09-23']);
      await _log(g, '2026-09-28', 1);
      expect(await _app.getStreak(g), 2);

      await _logAll(g, ['2026-09-29', '2026-09-30']);
      expect(await _app.getStreak(g), 3);
    });

    test('a current week that is already Off resets it to 0', () async {
      final g = await _goal('weekly', 'boolean', 'lte', 2);
      await _log(g, '2026-09-21', 1);
      await _log(g, '2026-09-14', 1);
      expect(await _app.getStreak(g), 2);

      await _logAll(g, ['2026-09-28', '2026-09-29', '2026-09-30']);
      expect(await _app.getStreak(g), 0);
    });

    test('a week without entries breaks it', () async {
      final g = await _goal('weekly', 'boolean', 'gte', 1);
      await _log(g, '2026-09-21', 1);
      await _log(g, '2026-09-07', 1);
      expect(await _app.getStreak(g), 1);
    });
  });

  group('on-target percentage', () {
    test('is null when nothing is logged', () async {
      final g = await _goal('daily', 'boolean', 'gte', 1);
      expect(await _app.getOnTargetPct(g, 7), isNull);
    });

    test('skips days without entries', () async {
      final g = await _goal('daily', 'boolean', 'gte', 1);
      await _logAll(g, ['2026-09-26', '2026-09-29']);
      await _log(g, '2026-09-28', 0);
      expect(await _app.getOnTargetPct(g, 7), closeTo(66.67, 0.01));
    });

    test("counts today's daily entry as soon as it's logged, hit or miss", () async {
      final g = await _goal('daily', 'number', 'gte', 30);
      await _log(g, '2026-09-30', 20);
      expect(await _app.getOnTargetPct(g, 7), 0);
    });

    test('ignores an undecided current week, counts a failed one', () async {
      final g = await _goal('weekly', 'boolean', 'lte', 2);
      await _log(g, '2026-09-21', 1);
      await _log(g, '2026-09-28', 1);
      expect(await _app.getOnTargetPct(g, 4), 100);

      await _logAll(g, ['2026-09-29', '2026-09-30']);
      expect(await _app.getOnTargetPct(g, 4), 50);
    });

    test('only looks at the requested window', () async {
      final g = await _goal('daily', 'boolean', 'gte', 1);
      await _log(g, '2026-09-01', 0);
      await _log(g, '2026-09-29', 1);
      expect(await _app.getOnTargetPct(g, 7), 100);
      expect(await _app.getOnTargetPct(g, 30), 50);
    });
  });

  group('History statuses', () {
    test('a weekly total includes days outside the listed range', () async {
      final g = await _goal('weekly', 'boolean', 'gte', 2);
      await _logAll(g, ['2026-09-21', '2026-09-27']);
      // Only Sunday the 27th is listed, but Monday the 21st is in its week.
      final rows = (await _app.getAllEntries('2026-09-27', '2026-09-27'))
          .where((r) => r['goal_id'] == g.id)
          .toList();
      final statuses = await _app.getEntryStatuses(rows);
      expect(statuses.single.toString(), 'On target');
    });

    test('daily rows are judged on their own value', () async {
      final g = await _goal('daily', 'number', 'gte', 30);
      await _log(g, '2026-09-29', 45);
      await _log(g, '2026-09-30', 20);
      final rows = (await _app.getAllEntries('2026-09-29', '2026-09-30'))
          .where((r) => r['goal_id'] == g.id)
          .toList();
      final statuses = await _app.getEntryStatuses(rows);
      expect(statuses.map((s) => s.label), ['Off', 'On target']);
    });
  });

  test('deleting a goal deletes its entries', () async {
    final g = await _goal('daily', 'boolean', 'gte', 1);
    await _logAll(g, ['2026-09-29', '2026-09-30']);
    await _app.deleteGoal(g.id!);
    expect(await _app.getGoal(g.id!), isNull);
    expect(await _app.getEntriesForGoal(g.id!, '2000-01-01', '2100-01-01'), isEmpty);
  });

  test('a new database starts with the default goals', () async {
    final goals = await _app.getGoals();
    expect(goals, hasLength(6));
    expect(goals.map((g) => g.evalPeriod).toSet(), {'daily', 'weekly'});
  });

  test('upgrading a version 1 database', () async {
    final dir = await Directory.systemTemp.createTemp('goalstat_test');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'v1.db');

    final v1 = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE goals (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                category TEXT NOT NULL DEFAULT 'Habits',
                type TEXT NOT NULL DEFAULT 'boolean',
                unit TEXT,
                frequency TEXT NOT NULL DEFAULT 'daily',
                eval_period TEXT NOT NULL DEFAULT 'daily',
                target_value REAL DEFAULT 1.0,
                target_direction TEXT NOT NULL DEFAULT 'gte',
                sort_order INTEGER DEFAULT 0,
                active INTEGER DEFAULT 1
              )''');
            await db.execute('''
              CREATE TABLE entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                goal_id INTEGER NOT NULL REFERENCES goals(id),
                date TEXT NOT NULL,
                value REAL NOT NULL DEFAULT 0,
                UNIQUE(goal_id, date)
              )''');
          },
        ));
    await v1.insert('goals', {'name': 'Kept', 'active': 1});
    await v1.insert('goals', {'name': 'Removed', 'active': 0});
    await v1.insert('goals',
        {'name': 'Logged weekly', 'frequency': 'weekly', 'eval_period': 'daily'});
    await v1.insert('entries', {'goal_id': 1, 'date': '2026-09-28', 'value': 1});
    await v1.insert('entries', {'goal_id': 2, 'date': '2026-09-28', 'value': 1});
    await v1.insert('entries', {'goal_id': 3, 'date': '2026-09-28', 'value': 3});
    await v1.close();

    final upgraded = await AppDatabase.openAt(path, factory: databaseFactoryFfi);
    addTearDown(upgraded.close);
    AppDatabase.useForTesting(upgraded);

    final goals = await _app.getGoals();
    expect(goals.map((g) => g.name), ['Kept', 'Logged weekly']);
    expect(goals.last.evalPeriod, 'weekly');
    final entries = await upgraded.query('entries', orderBy: 'goal_id');
    expect(entries.map((e) => e['goal_id']), [1, 3]);
  });
}
