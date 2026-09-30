import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../models/goal.dart';
import '../theme.dart';
import '../widgets/toggle_switch.dart';

class TodayScreen extends StatefulWidget {
  final VoidCallback onSaved;
  const TodayScreen({super.key, required this.onSaved});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final _db = AppDatabase.instance;
  List<Goal> _goals = [];
  final Map<int, double> _values = {};
  final Map<int, String> _dates = {};
  bool _saving = false;
  bool _saved = false;
  final Map<int, double> _weeklySums = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goals = await _db.getGoals();
    final today = DateTime.now();
    final todayStr = _fmtDate(today);
    final monday = _weekMonday(today);
    final mondayStr = _fmtDate(monday);
    final sundayStr = _fmtDate(monday.add(const Duration(days: 6)));

    final Map<int, double> values = {};
    final Map<int, String> dates = {};
    final Map<int, double> weeklySums = {};

    for (final g in goals) {
      final dateStr = g.isWeeklyFreq ? mondayStr : todayStr;
      dates[g.id!] = dateStr;
      final entry = await _db.getEntry(g.id!, dateStr);
      values[g.id!] = entry?.value ?? (g.isBoolean ? 0.0 : 0.0);

      if (g.isWeeklyEval && !g.isWeeklyFreq) {
        weeklySums[g.id!] = await _db.getWeeklySum(g.id!, mondayStr, sundayStr);
      }
    }

    if (mounted) {
      setState(() {
        _goals = goals;
        _values.addAll(values);
        _dates.addAll(dates);
        _weeklySums.addAll(weeklySums);
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    for (final g in _goals) {
      await _db.saveEntry(g.id!, _dates[g.id!]!, _values[g.id!] ?? 0);
    }
    setState(() { _saving = false; _saved = true; });
    widget.onSaved();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _saved = false);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final byCategory = <String, List<Goal>>{};
    for (final g in _goals) {
      byCategory.putIfAbsent(g.category, () => []).add(g);
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Today\'s Check-in'),
            Text(
              DateFormat('EEEE, MMMM d, y').format(today),
              style: const TextStyle(fontSize: 13, color: kMuted, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _goals.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: byCategory.entries.map((entry) {
                      return _CategoryGroup(
                        category: entry.key,
                        goals: entry.value,
                        values: _values,
                        weeklySums: _weeklySums,
                        onChanged: (gid, val) => setState(() => _values[gid] = val),
                      );
                    }).toList(),
                  ),
          ),
          _SaveBar(saving: _saving, saved: _saved, onSave: _save),
        ],
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  final String category;
  final List<Goal> goals;
  final Map<int, double> values;
  final Map<int, double> weeklySums;
  final void Function(int goalId, double val) onChanged;

  const _CategoryGroup({
    required this.category,
    required this.goals,
    required this.values,
    required this.weeklySums,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              category.toUpperCase(),
              style: const TextStyle(
                color: kMuted, fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 1.2),
            ),
          ),
          ...goals.asMap().entries.map((e) {
            final idx = e.key;
            final g = e.value;
            return Column(
              children: [
                if (idx > 0) const Divider(height: 1, color: kBorder),
                _GoalRow(
                  goal: g,
                  value: values[g.id!] ?? 0,
                  weeklySum: weeklySums[g.id!],
                  onChanged: (val) => onChanged(g.id!, val),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final Goal goal;
  final double value;
  final double? weeklySum;
  final ValueChanged<double> onChanged;

  const _GoalRow({
    required this.goal,
    required this.value,
    this.weeklySum,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    String? context_;
    if (weeklySum != null && !goal.isWeeklyFreq) {
      final sym = goal.directionSymbol;
      final t = goal.targetValue.toInt();
      context_ = 'This week: ${weeklySum!.toInt()} times  (goal: $sym $t/week)';
    } else if (goal.isWeeklyFreq) {
      context_ = 'Logged once per week';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                if (context_ != null) ...[
                  const SizedBox(height: 2),
                  Text(context_, style: const TextStyle(fontSize: 11, color: kMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (goal.isBoolean)
            GoalToggle(
              value: value >= 1,
              onChanged: (v) => onChanged(v ? 1.0 : 0.0),
            )
          else
            SizedBox(
              width: 130,
              child: _NumberInput(goal: goal, value: value, onChanged: onChanged),
            ),
        ],
      ),
    );
  }
}

class _NumberInput extends StatefulWidget {
  final Goal goal;
  final double value;
  final ValueChanged<double> onChanged;

  const _NumberInput({required this.goal, required this.value, required this.onChanged});

  @override
  State<_NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<_NumberInput> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.value == 0 ? '' : widget.value.toString());
  }

  @override
  void didUpdateWidget(_NumberInput old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_ctrl.text.isNotEmpty) {
      _ctrl.text = widget.value == 0 ? '' : widget.value.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(color: kText),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: const TextStyle(color: kMuted),
        suffixText: widget.goal.unit,
        suffixStyle: const TextStyle(color: kMuted, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onChanged: (s) {
        final v = double.tryParse(s);
        if (v != null) widget.onChanged(v);
      },
    );
  }
}

class _SaveBar extends StatelessWidget {
  final bool saving;
  final bool saved;
  final VoidCallback onSave;

  const _SaveBar({required this.saving, required this.saved, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      color: kSurface,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: saving ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: saved ? kGreen : kPurple,
            foregroundColor: kBg,
          ),
          child: saving
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kBg))
              : Text(
                  saved ? 'Saved!' : 'Save Today\'s Entry',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _weekMonday(DateTime d) => d.subtract(Duration(days: d.weekday - 1));
