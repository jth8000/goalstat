import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../data/database.dart';
import '../models/goal.dart';
import '../models/entry.dart';
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
    final monthAgo = today.subtract(const Duration(days: 30));
    final weekAgo = today.subtract(const Duration(days: 7));

    final cards = <_GoalData>[];
    for (final g in goals) {
      final streak = await _db.getStreak(g);
      final weekResult = await _db.getOnTargetPct(g, _fmt(weekAgo), _fmt(today));
      final monthResult = await _db.getOnTargetPct(g, _fmt(monthAgo), _fmt(today));
      final weekPct = weekResult.$3;
      final monthPct = monthResult.$3;
      final entries = await _db.getEntriesForGoal(
          g.id!, _fmt(monthAgo), _fmt(today));
      cards.add(_GoalData(
          goal: g, streak: streak, weekPct: weekPct, monthPct: monthPct,
          entries: entries));
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
  final double weekPct;
  final double monthPct;
  final List<Entry> entries;

  const _GoalData({
    required this.goal,
    required this.streak,
    required this.weekPct,
    required this.monthPct,
    required this.entries,
  });
}

class _GoalCard extends StatelessWidget {
  final _GoalData data;
  const _GoalCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final g = data.goal;
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
                    value: g.isWeeklyFreq
                        ? '${data.streak}w'
                        : '${data.streak}d'),
                const SizedBox(width: 20),
                _Stat(label: '7-day', value: '${data.weekPct.toStringAsFixed(0)}%',
                    color: pctColor(data.weekPct)),
                const SizedBox(width: 20),
                _Stat(label: '30-day', value: '${data.monthPct.toStringAsFixed(0)}%',
                    color: pctColor(data.monthPct)),
                const Spacer(),
                Text(
                  '${g.directionSymbol} ${g.targetValue % 1 == 0 ? g.targetValue.toInt() : g.targetValue}'
                  '${g.unit != null ? " ${g.unit}" : ""}',
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

class _GoalChart extends StatelessWidget {
  final _GoalData data;
  const _GoalChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final g = data.goal;
    if (g.isWeeklyEval || g.isWeeklyFreq) {
      return _WeeklyBarChart(data: data);
    } else if (g.isBoolean) {
      return _BooleanGrid(data: data);
    } else {
      return _NumberLineChart(data: data);
    }
  }
}

// 10-week bar chart for weekly goals
class _WeeklyBarChart extends StatelessWidget {
  final _GoalData data;
  const _WeeklyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final g = data.goal;
    final today = DateTime.now();
    final weeks = <String, double>{};

    for (int i = 9; i >= 0; i--) {
      final mon = _weekMonday(today.subtract(Duration(days: i * 7)));
      weeks[_fmt(mon)] = 0;
    }
    for (final e in data.entries) {
      final mon = _weekMonday(DateTime.parse(e.date));
      final key = _fmt(mon);
      if (weeks.containsKey(key)) weeks[key] = (weeks[key] ?? 0) + e.value;
    }

    final vals = weeks.values.toList();
    final maxY = (vals.isEmpty ? g.targetValue : vals.reduce((a, b) => a > b ? a : b))
        .clamp(g.targetValue, double.infinity) * 1.3;

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY,
      barGroups: vals.asMap().entries.map((e) {
        final onTarget = g.isOnTarget(e.value);
        return BarChartGroupData(x: e.key, barRods: [
          BarChartRodData(
            toY: e.value == 0 ? 0.05 : e.value,
            color: onTarget ? kGreen : kRed,
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
          final d = today.subtract(Duration(days: cols - 1 - i));
          final key = _fmt(d);
          final val = entryMap[key];
          Color color;
          if (val == null) {
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
          color: kPurple,
          barWidth: 2,
          dotData: const FlDotData(show: false),
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

DateTime _weekMonday(DateTime d) => d.subtract(Duration(days: d.weekday - 1));
