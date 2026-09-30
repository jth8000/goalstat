import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/goal.dart';
import '../models/entry.dart';
import '../models/period_status.dart';

const _defaultGoals = [
  {
    'name': 'Cardio', 'category': 'Fitness', 'type': 'boolean',
    'unit': null, 'eval_period': 'daily',
    'target_value': 1.0, 'target_direction': 'gte', 'sort_order': 1,
  },
  {
    'name': 'Strength Training', 'category': 'Fitness', 'type': 'boolean',
    'unit': null, 'eval_period': 'daily',
    'target_value': 1.0, 'target_direction': 'gte', 'sort_order': 2,
  },
  {
    'name': 'Water Intake', 'category': 'Fitness', 'type': 'number',
    'unit': 'oz', 'eval_period': 'daily',
    'target_value': 64.0, 'target_direction': 'gte', 'sort_order': 3,
  },
  {
    'name': 'Eating Out', 'category': 'Habits', 'type': 'boolean',
    'unit': null, 'eval_period': 'weekly',
    'target_value': 2.0, 'target_direction': 'lte', 'sort_order': 4,
  },
  {
    'name': 'Screen Time', 'category': 'Habits', 'type': 'number',
    'unit': 'hrs', 'eval_period': 'daily',
    'target_value': 3.0, 'target_direction': 'lte', 'sort_order': 5,
  },
  {
    'name': 'Read', 'category': 'Habits', 'type': 'boolean',
    'unit': null, 'eval_period': 'daily',
    'target_value': 1.0, 'target_direction': 'gte', 'sort_order': 6,
  },
];

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class AppDatabase {
  static AppDatabase? _instance;
  Database? _db;

  AppDatabase._();

  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  /// Current time used by the analytics; tests pin it.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// Makes [instance] use [db], e.g. an in-memory database from [openAt].
  @visibleForTesting
  static void useForTesting(Database db) => _instance = AppDatabase._().._db = db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationDocumentsDirectory();
    return openAt(p.join(dir.path, 'goalstat.db'));
  }

  /// Opens the database at [path], creating or upgrading it as needed.
  static Future<Database> openAt(String path, {DatabaseFactory? factory}) =>
      (factory ?? databaseFactory).openDatabase(path,
          options: OpenDatabaseOptions(
            version: 3,
            onCreate: _onCreate,
            onUpgrade: _onUpgrade,
          ));

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Goals used to be soft-deleted; purge them now that deletion is permanent.
      await db.execute(
          'DELETE FROM entries WHERE goal_id IN (SELECT id FROM goals WHERE active=0)');
      await db.execute('DELETE FROM goals WHERE active=0');
    }
    if (oldVersion < 3) {
      // The separate 'frequency' setting is gone; weekly-logged goals were
      // already evaluated weekly, but make sure.
      await db.execute(
          "UPDATE goals SET eval_period='weekly' WHERE frequency='weekly'");
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'Habits',
        type TEXT NOT NULL DEFAULT 'boolean',
        unit TEXT,
        eval_period TEXT NOT NULL DEFAULT 'daily',
        target_value REAL DEFAULT 1.0,
        target_direction TEXT NOT NULL DEFAULT 'gte',
        sort_order INTEGER DEFAULT 0,
        active INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL REFERENCES goals(id),
        date TEXT NOT NULL,
        value REAL NOT NULL DEFAULT 0,
        UNIQUE(goal_id, date)
      )
    ''');
    for (final g in _defaultGoals) {
      await db.insert('goals', Map<String, dynamic>.from(g));
    }
  }

  // --- Goals ---

  Future<List<Goal>> getGoals() async {
    final database = await db;
    final rows = await database.rawQuery('SELECT * FROM goals ORDER BY sort_order, id');
    return rows.map(Goal.fromMap).toList();
  }

  Future<Goal?> getGoal(int id) async {
    final database = await db;
    final rows = await database.query('goals', where: 'id=?', whereArgs: [id]);
    return rows.isEmpty ? null : Goal.fromMap(rows.first);
  }

  Future<int> addGoal(Goal goal) async {
    final database = await db;
    return database.insert('goals', goal.toMap());
  }

  Future<void> updateGoal(Goal goal) async {
    final database = await db;
    await database.update('goals', goal.toMap(), where: 'id=?', whereArgs: [goal.id]);
  }

  Future<void> deleteGoal(int id) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete('entries', where: 'goal_id=?', whereArgs: [id]);
      await txn.delete('goals', where: 'id=?', whereArgs: [id]);
    });
  }

  // --- Entries ---

  Future<Entry?> getEntry(int goalId, String date) async {
    final database = await db;
    final rows = await database.query('entries',
        where: 'goal_id=? AND date=?', whereArgs: [goalId, date]);
    return rows.isEmpty ? null : Entry.fromMap(rows.first);
  }

  Future<void> saveEntry(int goalId, String date, double value) async {
    final database = await db;
    await database.rawInsert('''
      INSERT INTO entries (goal_id, date, value) VALUES (?, ?, ?)
      ON CONFLICT(goal_id, date) DO UPDATE SET value=excluded.value
    ''', [goalId, date, value]);
  }

  Future<List<Entry>> getEntriesForGoal(int goalId, String start, String end) async {
    final database = await db;
    final rows = await database.query('entries',
        where: 'goal_id=? AND date>=? AND date<=?',
        whereArgs: [goalId, start, end],
        orderBy: 'date');
    return rows.map(Entry.fromMap).toList();
  }

  /// Every date ('yyyy-MM-dd') that has at least one entry.
  Future<Set<String>> getLoggedDates() async {
    final database = await db;
    final rows = await database.rawQuery('SELECT DISTINCT date FROM entries');
    return {for (final r in rows) r['date'] as String};
  }

  Future<DateTime?> getFirstEntryDate(int goalId) async {
    final database = await db;
    final rows = await database.rawQuery(
        'SELECT MIN(date) AS first FROM entries WHERE goal_id=?', [goalId]);
    final first = rows.first['first'] as String?;
    return first == null ? null : DateTime.parse(first);
  }

  Future<double> getPeriodSum(int goalId, String start, String end) async {
    final database = await db;
    final result = await database.rawQuery(
        'SELECT COALESCE(SUM(value), 0) as total FROM entries WHERE goal_id=? AND date>=? AND date<=?',
        [goalId, start, end]);
    return (result.first['total'] as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getAllEntries(String start, String end) async {
    final database = await db;
    return database.rawQuery('''
      SELECT e.date, e.value, e.goal_id,
             g.name, g.category, g.type, g.unit,
             g.eval_period, g.target_value, g.target_direction, g.sort_order
      FROM entries e
      JOIN goals g ON e.goal_id = g.id
      WHERE e.date >= ? AND e.date <= ?
      ORDER BY e.date DESC, g.sort_order
    ''', [start, end]);
  }

  // --- Analytics ---
  //
  // Entries are logged daily. A goal's eval period (day/week/month) decides
  // how they're totalled: each period's sum is compared against the target.
  // The current, in-progress period counts as a hit once it's on target and
  // as a miss once its status is Off (it can no longer succeed). Until then
  // it's ignored, so a half-finished week doesn't break a streak or drag
  // down a percentage. For daily goals, today counts toward percentages as
  // soon as it's logged, but can't break the streak until the day is over.

  Future<(Map<String, double>, bool)> _periodTotals(
      Goal goal, DateTime from) async {
    final todayStr = _fmt(clock());
    final entries = await getEntriesForGoal(
        goal.id!, _fmt(goal.periodStart(from)), todayStr);
    final totals = <String, double>{};
    for (final e in entries) {
      final key = _fmt(goal.periodStart(DateTime.parse(e.date)));
      totals[key] = (totals[key] ?? 0) + e.value;
    }
    return (totals, entries.any((e) => e.date == todayStr));
  }

  /// true = hit, false = miss, null = not decided yet.
  bool? _currentOutcome(Goal goal, double? total, bool loggedToday) {
    if (total != null && goal.isOnTarget(total)) return true;
    if (goal.isDailyEval) return null;
    final today = clock();
    final status = periodStatus(goal, total ?? 0, today,
        today: today, loggedToday: loggedToday);
    return status.level == StatusLevel.off ? false : null;
  }

  Future<int> getStreak(Goal goal) async {
    final today = clock();
    final (totals, loggedToday) = await _periodTotals(goal, DateTime(2000));
    int streak = 0;

    for (int i = 0; ; i++) {
      final total = totals[_fmt(goal.periodsAgo(today, i))];
      if (i == 0) {
        final outcome = _currentOutcome(goal, total, loggedToday);
        if (outcome == false) return 0;
        if (outcome == true) streak++;
        continue;
      }
      if (total == null || !goal.isOnTarget(total)) break;
      streak++;
    }
    return streak;
  }

  /// Percentage of the last [periods] periods (including the current one)
  /// that were on target. Periods with no entries are skipped; null when
  /// there's nothing to judge yet.
  Future<double?> getOnTargetPct(Goal goal, int periods) async {
    final today = clock();
    final (totals, loggedToday) =
        await _periodTotals(goal, goal.periodsAgo(today, periods - 1));
    final currentKey = _fmt(goal.periodStart(today));

    int onTarget = 0, total = 0;
    totals.forEach((key, sum) {
      final hit = key == currentKey && !goal.isDailyEval
          ? _currentOutcome(goal, sum, loggedToday)
          : goal.isOnTarget(sum);
      if (hit == null) return;
      total++;
      if (hit) onTarget++;
    });
    return total > 0 ? onTarget / total * 100 : null;
  }

  /// Status of each History row from [getAllEntries]. Daily goals are judged
  /// per entry; weekly/monthly goals by the total of the whole period each
  /// entry falls in, which may extend past the rows' date range.
  Future<List<PeriodStatus>> getEntryStatuses(List<Map<String, dynamic>> entries) async {
    final goals = {for (final g in await getGoals()) g.id!: g};
    final today = clock();
    final todayStr = _fmt(today);
    String periodKey(Goal g, String date) =>
        '${g.id}|${_fmt(g.periodStart(DateTime.parse(date)))}';

    DateTime? earliest;
    for (final e in entries) {
      final g = goals[e['goal_id']]!;
      if (g.isDailyEval) continue;
      final s = g.periodStart(DateTime.parse(e['date'] as String));
      if (earliest == null || s.isBefore(earliest)) earliest = s;
    }

    final totals = <String, double>{};
    final loggedToday = <int>{};
    if (earliest != null) {
      for (final e in await getAllEntries(_fmt(earliest), todayStr)) {
        final g = goals[e['goal_id']]!;
        if (g.isDailyEval) continue;
        final key = periodKey(g, e['date'] as String);
        totals[key] = (totals[key] ?? 0) + (e['value'] as num).toDouble();
        if (e['date'] == todayStr) loggedToday.add(g.id!);
      }
    }

    return entries.map((e) {
      final g = goals[e['goal_id']]!;
      final date = e['date'] as String;
      final total = g.isDailyEval
          ? (e['value'] as num).toDouble()
          : totals[periodKey(g, date)] ?? 0;
      return periodStatus(g, total, DateTime.parse(date),
          today: today, loggedToday: loggedToday.contains(g.id));
    }).toList();
  }
}
