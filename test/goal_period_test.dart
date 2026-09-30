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

  test('monthly periods cover the calendar month', () {
    final g = _goal('monthly');
    expect(g.periodStart(DateTime(2024, 2, 20)), DateTime(2024, 2, 1));
    expect(g.periodEnd(DateTime(2024, 2, 20)), DateTime(2024, 2, 29));
    expect(g.periodsAgo(d, 1), DateTime(2025, 12, 1));
    expect(g.periodsAgo(DateTime(2026, 3, 31), 1), DateTime(2026, 2, 1));
  });
}
