import 'goal.dart';

enum StatusLevel { onTarget, behind, off }

class PeriodStatus {
  final StatusLevel level;
  final String? detail;

  const PeriodStatus(this.level, [this.detail]);

  String get label => switch (level) {
        StatusLevel.onTarget => 'On target',
        StatusLevel.behind => 'Behind pace',
        StatusLevel.off => 'Off',
      };

  @override
  String toString() => detail == null ? label : '$label · $detail';
}

/// Status of the goal's period containing [date], given the period's [total].
///
/// Daily goals are simply on target or not. For weekly/monthly goals, a period
/// that has ended is judged on its total. One still in progress is judged on
/// whether the target is still reachable:
/// - at most: on target until the total goes over.
/// - at least / exactly, yes/no goals: on target while logging every
///   remaining day could still reach the target.
/// - at least / exactly, number goals: on target while keeping pace with the
///   share of the period that has passed; otherwise behind pace.
///
/// Today counts as a remaining day until something is logged for it.
PeriodStatus periodStatus(Goal g, double total, DateTime date,
    {required DateTime today, bool loggedToday = false}) {
  if (g.isDailyEval) {
    return PeriodStatus(g.isOnTarget(total) ? StatusLevel.onTarget : StatusLevel.off);
  }

  final start = _day(g.periodStart(date));
  final end = _day(g.periodEnd(date));
  final t = _day(today);
  final periodDays = end.difference(start).inDays + 1;
  final daysLeft = end.isBefore(t)
      ? 0
      : end.difference(t).inDays + (loggedToday ? 0 : 1);

  final target = g.targetValue;
  if (g.targetDirection != 'gte' && Goal.exceeds(total, target)) {
    return PeriodStatus(StatusLevel.off, 'over by ${_amount(g, total - target)}');
  }
  if (g.isOnTarget(total)) return const PeriodStatus(StatusLevel.onTarget);
  // Below an 'at least' or 'exactly' target from here on.
  if (daysLeft == 0) {
    return PeriodStatus(StatusLevel.off, '${_pct(total, target)}% of target');
  }
  if (g.isBoolean) {
    final maxPossible = total + daysLeft;
    return Goal.reaches(maxPossible, target)
        ? const PeriodStatus(StatusLevel.onTarget)
        : PeriodStatus(StatusLevel.off, '${_pct(maxPossible, target)}% max possible');
  }
  final elapsed = periodDays - daysLeft;
  return Goal.reaches(total, target * elapsed / periodDays)
      ? const PeriodStatus(StatusLevel.onTarget)
      : PeriodStatus(StatusLevel.behind, '${_pct(total, target)}% of target');
}

DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

int _pct(double value, double target) =>
    target <= 0 ? 100 : (value / target * 100).floor();

String _amount(Goal g, double v) {
  final n = v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
  return g.unit != null && !g.isBoolean ? '$n ${g.unit}' : n;
}
