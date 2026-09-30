import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../data/database.dart';
import '../models/goal.dart';
import '../models/entry.dart';
import '../models/period_status.dart';
import '../theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final _db = AppDatabase.instance;
  List<_GoalData> _cards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => _loading = true);
    final goals = await _db.getGoals();
    final today = DateTime.now();

    final cards = <_GoalData>[];
    for (final g in goals) {
      final streak = await _db.getStreak(g);
      final (shortN, longN) = _pctPeriods(g);
      final shortPct = await _db.getOnTargetPct(g, shortN);
      final longPct = await _db.getOnTargetPct(g, longN);
      final chartStart = g.periodsAgo(today, _chartPeriods(g) - 1);
      final entries = await _db.getEntriesForGoal(
          g.id!, _fmt(chartStart), _fmt(today));
      final firstEntry = await _db.getFirstEntryDate(g.id!);
      cards.add(_GoalData(
          goal: g, streak: streak, shortPct: shortPct, longPct: longPct,
          entries: entries, firstEntry: firstEntry));
    }

    if (mounted) setState(() { _cards = cards; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? const Center(child: Text('No goals yet. Add one in Settings.',
                  style: TextStyle(color: kMuted)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _cards.map((d) => _GoalCard(data: d)).toList(),
                ),
    );
  }
}

class _GoalData {
  final Goal goal;
  final int streak;
  final double? shortPct;
  final double? longPct;
  final List<Entry> entries;
  final DateTime? firstEntry;

  const _GoalData({
    required this.goal,
    required this.streak,
    required this.shortPct,
    required this.longPct,
    required this.entries,
    required this.firstEntry,
  });
}

class _GoalCard extends StatelessWidget {
  final _GoalData data;
  const _GoalCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final g = data.goal;
    final (shortN, longN) = _pctPeriods(g);
    final suffix = g.isWeeklyEval ? 'wk' : g.isMonthlyEval ? 'mo' : 'day';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                if (g.category.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(g.category,
                        style: const TextStyle(color: kPurple, fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(g.name,
                      style: const TextStyle(fontSize: 16,
                          fontWeight: FontWeight.bold, color: kText)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _Stat(label: 'Streak',
                    value: '${data.streak}${g.isWeeklyEval ? 'w' : g.isMonthlyEval ? 'mo' : 'd'}'),
                const SizedBox(width: 20),
                _PctStat(label: '$shortN-$suffix', pct: data.shortPct),
                const SizedBox(width: 20),
                _PctStat(label: '$longN-$suffix', pct: data.longPct),
                const Spacer(),
                Text(
                  '${g.targetLabel}'
                  '${g.unit != null ? " ${g.unit}" : ""}'
                  '${g.isDailyEval ? "" : " / ${g.periodNoun}"}',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _GoalChart(data: data),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kMuted, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color ?? kText, fontSize: 18,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _PctStat extends StatelessWidget {
  final String label;
  final double? pct;

  const _PctStat({required this.label, required this.pct});

  @override
  Widget build(BuildContext context) => pct == null
      ? _Stat(label: label, value: '—', color: kMuted)
      : _Stat(label: label, value: '${pct!.toStringAsFixed(0)}%',
          color: pctColor(pct!));
}

class _GoalChart extends StatelessWidget {
  final _GoalData data;
  const _GoalChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final g = data.goal;
    if (data.firstEntry == null) {
      return const Center(child: Text('No data yet', style: TextStyle(color: kMuted, fontSize: 12)));
    } else if (!g.isDailyEval) {
      return _PeriodBarChart(data: data);
    } else if (g.isBoolean) {
      return _BooleanGrid(data: data);
    } else {
      return _NumberLineChart(data: data);
    }
  }
}

// Bar per week (last 10) or month (last 12) for weekly/monthly goals
class _PeriodBarChart extends StatelessWidget {
  final _GoalData data;
  const _PeriodBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final g = data.goal;
    final today = DateTime.now();
    final totals = <String, double>{};

    for (int i = _chartPeriods(g) - 1; i >= 0; i--) {
      totals[_fmt(g.periodsAgo(today, i))] = 0;
    }
    for (final e in data.entries) {
      final key = _fmt(g.periodStart(DateTime.parse(e.date)));
      if (totals.containsKey(key)) totals[key] = totals[key]! + e.value;
    }

    final vals = totals.values.toList();
    final todayStr = _fmt(today);
    final loggedToday = data.entries.any((e) => e.date == todayStr);
    // Same status as Today/History: the current period can be on target
    // (still reachable), behind pace or off; past periods are final.
    // No bars for periods before the goal was first logged.
    final firstKey = _fmt(g.periodStart(data.firstEntry!));
    final colors = totals.keys.map((key) => key.compareTo(firstKey) < 0
        ? Colors.transparent
        : statusColor(periodStatus(g, totals[key]!, DateTime.parse(key),
            today: today, loggedToday: loggedToday).level)).toList();
    final maxY = (vals.isEmpty ? g.targetValue : vals.reduce((a, b) => a > b ? a : b))
        .clamp(g.targetValue, double.infinity) * 1.3;

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY,
      barGroups: vals.asMap().entries.map((e) {
        return BarChartGroupData(x: e.key, barRods: [
          BarChartRodData(
            toY: e.value == 0 ? 0.05 : e.value,
            color: colors[e.key],
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ]);
      }).toList(),
      titlesData: FlTitlesData(
        show: true,
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      extraLinesData: ExtraLinesData(horizontalLines: [
        HorizontalLine(y: g.targetValue, color: kPurple.withValues(alpha: 0.6),
            strokeWidth: 1, dashArray: [4, 4]),
      ]),
    ));
  }
}

// 30-day boolean grid
class _BooleanGrid extends StatelessWidget {
  final _GoalData data;
  const _BooleanGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final g = data.goal;
    final today = DateTime.now();
    final entryMap = {for (final e in data.entries) e.date: e.value};

    return LayoutBuilder(builder: (ctx, constraints) {
      const cols = 30;
      final cellW = (constraints.maxWidth - 29 * 3) / cols;
      final cellH = constraints.maxHeight;

      return Row(
        children: List.generate(cols, (i) {
          final d = DateTime(today.year, today.month, today.day - (cols - 1 - i));
          final key = _fmt(d);
          final val = entryMap[key];
          Color color;
          if (d.isBefore(data.firstEntry!)) {
            color = Colors.transparent;
          } else if (val == null) {
            color = kSurface2;
          } else {
            color = g.isOnTarget(val) ? kGreen : kRed;
          }
          return Container(
            width: cellW,
            height: cellH,
            margin: EdgeInsets.only(right: i < cols - 1 ? 3 : 0),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      );
    });
  }
}

// 30-day line chart for number goals
class _NumberLineChart extends StatelessWidget {
  final _GoalData data;
  const _NumberLineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final g = data.goal;
    final today = DateTime.now();
    final entryMap = {for (final e in data.entries) e.date: e.value};

    final spots = <FlSpot>[];
    for (int i = 0; i < 30; i++) {
      final d = today.subtract(Duration(days: 29 - i));
      final val = entryMap[_fmt(d)];
      if (val != null) spots.add(FlSpot(i.toDouble(), val));
    }

    if (spots.isEmpty) {
      return const Center(child: Text('No data yet', style: TextStyle(color: kMuted, fontSize: 12)));
    }

    final maxY = ([...spots.map((s) => s.y), g.targetValue]
        .reduce((a, b) => a > b ? a : b)) * 1.3;

    return LineChart(LineChartData(
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          preventCurveOverShooting: true,
          color: kPurple,
          barWidth: 2,
          // Days without entries are gaps, so mark the days that have one.
          dotData: FlDotData(
            getDotPainter: (spot, pct, bar, i) => FlDotCirclePainter(
                radius: 3, color: kPurple, strokeWidth: 0),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: kPurple.withValues(alpha: 0.12),
          ),
        ),
      ],
      extraLinesData: ExtraLinesData(horizontalLines: [
        HorizontalLine(y: g.targetValue, color: kPurple.withValues(alpha: 0.5),
            strokeWidth: 1, dashArray: [4, 4]),
      ]),
      titlesData: FlTitlesData(
        show: true,
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: kBorder.withValues(alpha: 0.3), strokeWidth: 1),
        drawVerticalLine: false,
      ),
      borderData: FlBorderData(show: false),
    ));
  }
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Periods covered by the short and long on-target percentages.
(int, int) _pctPeriods(Goal g) =>
    g.isWeeklyEval ? (4, 12) : g.isMonthlyEval ? (3, 12) : (7, 30);

/// Periods shown in the goal's chart.
int _chartPeriods(Goal g) =>
    g.isWeeklyEval ? 10 : g.isMonthlyEval ? 12 : 30;
