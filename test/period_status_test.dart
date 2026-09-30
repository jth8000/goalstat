import 'package:flutter_test/flutter_test.dart';
import 'package:goalstat/models/goal.dart';
import 'package:goalstat/models/period_status.dart';

Goal _goal(String evalPeriod, String type, String direction, double target,
        {String? unit}) =>
    Goal(
      name: 'g',
      category: '',
      type: type,
      unit: unit,
      evalPeriod: evalPeriod,
      targetValue: target,
      targetDirection: direction,
    );

void main() {
  // Wednesday 2026-09-30; its week runs Mon 28 Sep – Sun 4 Oct.
  final wed = DateTime(2026, 9, 30);
  String status(Goal g, double total,
          {DateTime? date, DateTime? today, bool logged = false}) =>
      periodStatus(g, total, date ?? wed, today: today ?? wed, loggedToday: logged)
          .toString();

  group('daily goals', () {
    test('judged on the day alone', () {
      final g = _goal('daily', 'boolean', 'gte', 1);
      expect(status(g, 1), 'On target');
      expect(status(g, 0), 'Off');
    });
  });

  group('weekly yes/no, at least', () {
    final g = _goal('weekly', 'boolean', 'gte', 5);

    test('on target while every remaining day could still reach it', () {
      // Wed unlogged: Wed–Sun = 5 days left.
      expect(status(g, 0), 'On target');
    });

    test('today stops counting as remaining once logged', () {
      // 0 so far, today logged as "no": Thu–Sun = 4 days left → max 4 of 5.
      expect(status(g, 0, logged: true), 'Off · 80% max possible');
    });

    test('ended week shows final percentage', () {
      final nextMon = DateTime(2026, 10, 5);
      expect(status(g, 3, today: nextMon), 'Off · 60% of target');
      expect(status(g, 5, today: nextMon), 'On target');
    });
  });

  group('weekly number, at least', () {
    final g = _goal('weekly', 'number', 'gte', 20, unit: 'hrs');

    test('on pace', () {
      // Mon & Tue done, Wed logged: 3 of 7 days elapsed → expect ≥ 8.57.
      expect(status(g, 9, logged: true), 'On target');
    });

    test('behind pace shows progress toward target', () {
      expect(status(g, 8, logged: true), 'Behind pace · 40% of target');
    });

    test('today unlogged does not count as elapsed', () {
      // Only Mon & Tue elapsed → expect ≥ 5.71.
      expect(status(g, 6), 'On target');
    });

    test('first day of the period is never behind before logging', () {
      expect(status(g, 0, date: DateTime(2026, 9, 28), today: DateTime(2026, 9, 28)),
          'On target');
    });
  });

  group('at most', () {
    final g = _goal('weekly', 'boolean', 'lte', 2);
    final hrs = _goal('monthly', 'number', 'lte', 20, unit: 'hrs');

    test('on target until the total goes over', () {
      expect(status(g, 2), 'On target');
      expect(status(g, 3), 'Off · over by 1');
      expect(status(hrs, 22.5), 'Off · over by 2.5 hrs');
    });
  });

  group('exactly', () {
    final g = _goal('weekly', 'boolean', 'eq', 3);

    test('off once over, otherwise like at least', () {
      expect(status(g, 4), 'Off · over by 1');
      expect(status(g, 3), 'On target');
      expect(status(g, 1), 'On target');
    });
  });

  group('monthly', () {
    final g = _goal('monthly', 'boolean', 'gte', 1);

    test('once-a-month yes/no goal is fine until the last day', () {
      expect(status(g, 0, date: DateTime(2026, 9, 2), today: DateTime(2026, 9, 2),
              logged: true),
          'On target');
      expect(status(g, 0, date: DateTime(2026, 9, 30), today: DateTime(2026, 9, 30),
              logged: true),
          'Off · 0% of target');
    });
  });
}
