import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../models/goal.dart';
import '../models/period_status.dart';
import '../theme.dart';
import '../widgets/toggle_switch.dart';

class TodayScreen extends StatefulWidget {
  final VoidCallback onSaved;
  const TodayScreen({super.key, required this.onSaved});

  @override
  State<TodayScreen> createState() => TodayScreenState();
}

class TodayScreenState extends State<TodayScreen> {
  final _db = AppDatabase.instance;
  List<Goal> _goals = [];
  final Map<int, double> _values = {};
  String _date = '';
  bool _loading = true;
  bool _saving = false;
  bool _saved = false;
  final Map<int, double> _periodSums = {};
  final Map<int, PeriodStatus> _statuses = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    final goals = await _db.getGoals();
    final today = DateTime.now();
    final todayStr = _fmtDate(today);

    final Map<int, double> values = {};
    final Map<int, double> periodSums = {};
    final Map<int, PeriodStatus> statuses = {};

    for (final g in goals) {
      final entry = await _db.getEntry(g.id!, todayStr);
      values[g.id!] = entry?.value ?? 0.0;

      if (!g.isDailyEval) {
        final sum = await _db.getPeriodSum(g.id!,
            _fmtDate(g.periodStart(today)), _fmtDate(g.periodEnd(today)));
        periodSums[g.id!] = sum;
        statuses[g.id!] = periodStatus(g, sum, today,
            today: today, loggedToday: entry != null);
      }
    }

    if (mounted) {
      setState(() {
        _goals = goals;
        _loading = false;
        _values.addAll(values);
        _date = todayStr;
        _periodSums.addAll(periodSums);
        _statuses.addAll(statuses);
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    for (final g in _goals) {
      await _db.saveEntry(g.id!, _date, _values[g.id!] ?? 0);
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _goals.isEmpty
                    ? const Center(child: Text('No goals yet. Add one in Settings.',
                        style: TextStyle(color: kMuted)))
                    : ListView(
                    padding: const EdgeInsets.all(16),
                    children: byCategory.entries.map((entry) {
                      return _CategoryGroup(
                        category: entry.key,
                        goals: entry.value,
                        values: _values,
                        periodSums: _periodSums,
                        statuses: _statuses,
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
  final Map<int, double> periodSums;
  final Map<int, PeriodStatus> statuses;
  final void Function(int goalId, double val) onChanged;

  const _CategoryGroup({
    required this.category,
    required this.goals,
    required this.values,
    required this.periodSums,
    required this.statuses,
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
          if (category.isNotEmpty)
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
                  periodSum: periodSums[g.id!],
                  status: statuses[g.id!],
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
  final double? periodSum;
  final PeriodStatus? status;
  final ValueChanged<double> onChanged;

  const _GoalRow({
    required this.goal,
    required this.value,
    this.periodSum,
    this.status,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    String? context_;
    if (periodSum != null) {
      final period = goal.periodNoun;
      final unit = goal.isBoolean ? ' times' : (goal.unit != null ? ' ${goal.unit}' : '');
      context_ = 'This $period: ${_num(periodSum!)}$unit  '
          '(goal: ${goal.directionSymbol} ${_num(goal.targetValue)}/$period)';
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
                if (status != null) ...[
                  const SizedBox(height: 2),
                  Text(status.toString(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: statusColor(status!.level))),
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

String _num(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();
