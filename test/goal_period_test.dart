import 'package:flutter_test/flutter_test.dart';
import 'package:goalstat/models/goal.dart';

Goal _goal(String evalPeriod) => Goal(
      name: 'g',
      category: '',
      type: 'boolean',
      evalPeriod: evalPeriod,
      targetValue: 1,
      targetDirection: 'gte',
    );

void main() {
  // Thursday
  final d = DateTime(2026, 1, 1, 15, 30);

  test('daily periods are single days', () {
    final g = _goal('daily');
    expect(g.periodStart(d), DateTime(2026, 1, 1));
    expect(g.periodEnd(d), DateTime(2026, 1, 1));
    expect(g.periodsAgo(d, 1), DateTime(2025, 12, 31));
  });

  test('weekly periods run Monday to Sunday across a year boundary', () {
    final g = _goal('weekly');
    expect(g.periodStart(d), DateTime(2025, 12, 29));
    expect(g.periodEnd(d), DateTime(2026, 1, 4));
    expect(g.periodsAgo(d, 2), DateTime(2025, 12, 15));
  });

  test('weekly periods follow a Sunday week start', () {
    Goal.firstWeekday = DateTime.sunday;
    addTearDown(() => Goal.firstWeekday = DateTime.monday);
    final g = _goal('weekly');
    expect(g.periodStart(d), DateTime(2025, 12, 28));
    expect(g.periodEnd(d), DateTime(2026, 1, 3));
    // A Sunday starts its own week rather than ending the previous one.
    expect(g.periodStart(DateTime(2026, 1, 4)), DateTime(2026, 1, 4));
    expect(g.periodsAgo(d, 1), DateTime(2025, 12, 21));
  });

  test('monthly periods cover the calendar month', () {
    final g = _goal('monthly');
    expect(g.periodStart(DateTime(2024, 2, 20)), DateTime(2024, 2, 1));
    expect(g.periodEnd(DateTime(2024, 2, 20)), DateTime(2024, 2, 29));
    expect(g.periodsAgo(d, 1), DateTime(2025, 12, 1));
    expect(g.periodsAgo(DateTime(2026, 3, 31), 1), DateTime(2026, 2, 1));
  });

  // Run with e.g. TZ=America/New_York to exercise real clock changes
  // (2026: Mar 8 spring forward, Nov 1 fall back in the US).
  group('across daylight-saving changes', () {
    test('stepping back by days never skips or repeats a date', () {
      final g = _goal('daily');
      for (final start in [DateTime(2026, 3, 10), DateTime(2026, 11, 3)]) {
        final days = [for (var i = 0; i < 4; i++) g.periodsAgo(start, i)];
        for (var i = 1; i < days.length; i++) {
          final prev = days[i - 1], d = days[i];
          expect(DateTime.utc(prev.year, prev.month, prev.day)
              .difference(DateTime.utc(d.year, d.month, d.day)).inDays, 1);
          expect(d.hour, 0);
        }
      }
    });

    test('weeks containing a clock change keep 7 days', () {
      Goal.firstWeekday = DateTime.sunday;
      addTearDown(() => Goal.firstWeekday = DateTime.monday);
      final g = _goal('weekly');
      expect(g.periodStart(DateTime(2026, 3, 8, 12)), DateTime(2026, 3, 8));
      expect(g.periodEnd(DateTime(2026, 3, 8, 12)), DateTime(2026, 3, 14));
      expect(g.periodStart(DateTime(2026, 11, 7, 23, 30)), DateTime(2026, 11, 1));
      expect(g.periodsAgo(DateTime(2026, 3, 15), 1), DateTime(2026, 3, 8));
      expect(g.periodsAgo(DateTime(2026, 11, 8), 1), DateTime(2026, 11, 1));
    });
  });
}
