import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/goal.dart';
import '../models/entry.dart';

const _defaultGoals = [
  {
    'name': 'Cardio', 'category': 'Fitness', 'type': 'boolean',
    'unit': null, 'frequency': 'daily', 'eval_period': 'daily',
    'target_value': 1.0, 'target_direction': 'gte', 'sort_order': 1,
  },
  {
    'name': 'Strength Training', 'category': 'Fitness', 'type': 'boolean',
    'unit': null, 'frequency': 'daily', 'eval_period': 'daily',
    'target_value': 1.0, 'target_direction': 'gte', 'sort_order': 2,
  },
  {
    'name': 'Water Intake', 'category': 'Fitness', 'type': 'number',
    'unit': 'oz', 'frequency': 'daily', 'eval_period': 'daily',
    'target_value': 64.0, 'target_direction': 'gte', 'sort_order': 3,
  },
  {
    'name': 'Eating Out', 'category': 'Habits', 'type': 'boolean',
    'unit': null, 'frequency': 'daily', 'eval_period': 'weekly',
    'target_value': 2.0, 'target_direction': 'lte', 'sort_order': 4,
  },
  {
    'name': 'Screen Time', 'category': 'Habits', 'type': 'number',
    'unit': 'hrs', 'frequency': 'daily', 'eval_period': 'daily',
    'target_value': 3.0, 'target_direction': 'lte', 'sort_order': 5,
  },
  {
    'name': 'Read', 'category': 'Habits', 'type': 'boolean',
    'unit': null, 'frequency': 'daily', 'eval_period': 'daily',
    'target_value': 1.0, 'target_direction': 'gte', 'sort_order': 6,
  },
];

String weekMonday(DateTime d) {
  final mon = d.subtract(Duration(days: d.weekday - 1));
  return _fmt(mon);
}

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
    final path = p.join(dir.path, 'goalstat.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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

  Future<List<Goal>> getGoals({bool activeOnly = true}) async {
    final database = await db;
    final q = activeOnly
        ? 'SELECT * FROM goals WHERE active=1 ORDER BY sort_order, id'
        : 'SELECT * FROM goals ORDER BY sort_order, id';
    final rows = await database.rawQuery(q);
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

  Future<void> deactivateGoal(int id) async {
    final database = await db;
    await database.update('goals', {'active': 0}, where: 'id=?', whereArgs: [id]);
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

  Future<double> getWeeklySum(int goalId, String monday, String sunday) async {
    final database = await db;
    final result = await database.rawQuery(
        'SELECT COALESCE(SUM(value), 0) as total FROM entries WHERE goal_id=? AND date>=? AND date<=?',
        [goalId, monday, sunday]);
    return (result.first['total'] as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getAllEntries(String start, String end) async {
    final database = await db;
    return database.rawQuery('''
      SELECT e.date, e.value, e.goal_id,
             g.name, g.category, g.type, g.unit,
             g.frequency, g.eval_period, g.target_value, g.target_direction, g.sort_order
      FROM entries e
      JOIN goals g ON e.goal_id = g.id
      WHERE e.date >= ? AND e.date <= ? AND g.active = 1
      ORDER BY e.date DESC, g.sort_order
    ''', [start, end]);
  }

  // --- Analytics ---

  Future<int> getStreak(Goal goal) async {
    final today = DateTime.now();
    final todayStr = _fmt(today);
    int streak = 0;

    if (goal.isWeeklyEval) {
      DateTime check = today;
      for (int i = 0; i < 520; i++) {
        final mon = check.subtract(Duration(days: check.weekday - 1));
        final sun = mon.add(const Duration(days: 6));
        final monStr = _fmt(mon);
        final sunStr = _fmt(sun);
        final entries = await getEntriesForGoal(goal.id!, monStr, sunStr);
        if (entries.isEmpty) {
          if (monStr == weekMonday(today)) {
            check = mon.subtract(const Duration(days: 1));
            continue;
          }
          break;
        }
        final total = entries.fold(0.0, (s, e) => s + e.value);
        if (goal.isOnTarget(total)) {
          streak++;
          check = mon.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    } else {
      DateTime check = today;
      for (int i = 0; i < 3650; i++) {
        final dateStr = _fmt(check);
        final entry = await getEntry(goal.id!, dateStr);
        if (entry == null) {
          if (dateStr == todayStr) {
            check = check.subtract(const Duration(days: 1));
            continue;
          }
          break;
        }
        if (goal.isOnTarget(entry.value)) {
          streak++;
          check = check.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }
    return streak;
  }

  Future<(int, int, double)> getOnTargetPct(
      Goal goal, String start, String end) async {
    final entries = await getEntriesForGoal(goal.id!, start, end);
    if (entries.isEmpty) return (0, 0, 0.0);

    int onTarget, total;

    if (goal.isWeeklyEval) {
      final weeks = <String, List<double>>{};
      for (final e in entries) {
        final mon = weekMonday(DateTime.parse(e.date));
        weeks.putIfAbsent(mon, () => []).add(e.value);
      }
      onTarget = weeks.values
          .where((vals) => goal.isOnTarget(vals.fold(0.0, (a, b) => a + b)))
          .length;
      total = weeks.length;
    } else {
      onTarget = entries.where((e) => goal.isOnTarget(e.value)).length;
      total = entries.length;
    }

    final pct = total > 0 ? onTarget / total * 100 : 0.0;
    return (onTarget, total, pct);
  }
}
