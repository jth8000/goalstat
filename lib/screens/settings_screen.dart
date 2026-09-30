import 'package:flutter/material.dart';

import '../data/database.dart';
import '../models/goal.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onGoalsChanged;
  const SettingsScreen({super.key, required this.onGoalsChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = AppDatabase.instance;
  List<Goal> _goals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goals = await _db.getGoals(activeOnly: false);
    if (mounted) setState(() => _goals = goals);
  }

  void _add() async {
    final data = await showDialog<_GoalFormData>(
        context: context, builder: (_) => const _GoalDialog());
    if (data == null) return;
    await _db.addGoal(data.toGoal());
    _load();
    widget.onGoalsChanged();
  }

  void _edit(Goal g) async {
    final data = await showDialog<_GoalFormData>(
        context: context, builder: (_) => _GoalDialog(goal: g));
    if (data == null) return;
    await _db.updateGoal(data.toGoal(id: g.id));
    _load();
    widget.onGoalsChanged();
  }

  void _delete(Goal g) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Goal'),
        content: Text('Remove "${g.name}"?\n\nExisting entries will be kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: kRed)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _db.deactivateGoal(g.id!);
    _load();
    widget.onGoalsChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add, color: kPurple),
            label: const Text('Add Goal', style: TextStyle(color: kPurple)),
            onPressed: _add,
          ),
        ],
      ),
      body: _goals.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _goals.length,
              separatorBuilder: (context, idx) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _GoalTile(
                goal: _goals[i],
                onEdit: () => _edit(_goals[i]),
                onDelete: _goals[i].active ? () => _delete(_goals[i]) : null,
              ),
            ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final Goal goal;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _GoalTile({required this.goal, required this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final g = goal;
    final freq = g.isWeeklyFreq ? 'Weekly' : 'Daily';
    final eval = g.isWeeklyEval && !g.isWeeklyFreq ? ' / Weekly eval' : '';
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (!g.active)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: kMuted.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Inactive',
                          style: TextStyle(color: kMuted, fontSize: 10)),
                    ),
                  Text(g.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: g.active ? kText : kMuted,
                      )),
                ]),
                const SizedBox(height: 4),
                Text(
                  '${g.category}  ·  ${g.isBoolean ? "Yes/No" : "Number${g.unit != null ? " (${g.unit})" : ""}"}  ·  $freq$eval  ·  ${g.directionSymbol} ${g.targetValue % 1 == 0 ? g.targetValue.toInt() : g.targetValue}',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: kMuted, size: 20),
            onPressed: onEdit,
            tooltip: 'Edit',
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: kRed, size: 20),
              onPressed: onDelete,
              tooltip: 'Remove',
            ),
        ],
      ),
    );
  }
}

// ---------- Goal Dialog ----------

class _GoalFormData {
  final String name;
  final String category;
  final String type;
  final String? unit;
  final String frequency;
  final String evalPeriod;
  final double targetValue;
  final String targetDirection;

  const _GoalFormData({
    required this.name,
    required this.category,
    required this.type,
    this.unit,
    required this.frequency,
    required this.evalPeriod,
    required this.targetValue,
    required this.targetDirection,
  });

  Goal toGoal({int? id}) => Goal(
    id: id,
    name: name, category: category, type: type, unit: unit,
    frequency: frequency, evalPeriod: evalPeriod,
    targetValue: targetValue, targetDirection: targetDirection,
  );
}

class _GoalDialog extends StatefulWidget {
  final Goal? goal;
  const _GoalDialog({this.goal});

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  String _category = 'Habits';
  String _type = 'boolean';
  String _frequency = 'daily';
  String _evalPeriod = 'daily';
  String _direction = 'gte';

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    if (g != null) {
      _nameCtrl.text = g.name;
      _category = g.category;
      _type = g.type;
      _unitCtrl.text = g.unit ?? '';
      _frequency = g.frequency;
      _evalPeriod = g.evalPeriod;
      _targetCtrl.text = g.targetValue.toString();
      _direction = g.targetDirection;
    } else {
      _targetCtrl.text = '1.0';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _unitCtrl.dispose(); _targetCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal name is required.')));
      return;
    }
    final target = double.tryParse(_targetCtrl.text) ?? 1.0;
    final unit = _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim();
    Navigator.pop(context, _GoalFormData(
      name: _nameCtrl.text.trim(),
      category: _category,
      type: _type,
      unit: _type == 'boolean' ? null : unit,
      frequency: _frequency,
      evalPeriod: _frequency == 'weekly' ? 'weekly' : _evalPeriod,
      targetValue: target,
      targetDirection: _direction,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.goal == null ? 'Add Goal' : 'Edit Goal'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('Name', TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(hintText: 'e.g. Morning Run'),
            )),
            _field('Category', _DropdownField<String>(
              value: _category,
              items: const ['Habits', 'Career', 'Exploration'],
              onChanged: (v) => setState(() => _category = v!),
            )),
            _field('Type', _DropdownField<String>(
              value: _type,
              items: const ['boolean', 'number'],
              labels: const ['Yes / No', 'Number'],
              onChanged: (v) => setState(() => _type = v!),
            )),
            if (_type == 'number')
              _field('Unit', TextField(
                controller: _unitCtrl,
                decoration: const InputDecoration(hintText: 'e.g. hrs, apps'),
              )),
            _field('Frequency', _DropdownField<String>(
              value: _frequency,
              items: const ['daily', 'weekly'],
              labels: const ['Daily', 'Weekly'],
              onChanged: (v) => setState(() {
                _frequency = v!;
                if (_frequency == 'weekly') _evalPeriod = 'weekly';
              }),
            )),
            if (_frequency == 'daily')
              _field('Evaluate', _DropdownField<String>(
                value: _evalPeriod,
                items: const ['daily', 'weekly'],
                labels: const ['Daily', 'Weekly'],
                onChanged: (v) => setState(() => _evalPeriod = v!),
              )),
            _field('Direction', _DropdownField<String>(
              value: _direction,
              items: const ['gte', 'lte', 'eq'],
              labels: const ['≥  at least', '≤  at most', '=  exactly'],
              onChanged: (v) => setState(() => _direction = v!),
            )),
            _field('Target', TextField(
              controller: _targetCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            )),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit,
            child: Text(widget.goal == null ? 'Add' : 'Save')),
      ],
    );
  }

  Widget _field(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kMuted, fontSize: 12)),
        const SizedBox(height: 4),
        child,
      ],
    ),
  );
}

class _DropdownField<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final List<String>? labels;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.value, required this.items,
    this.labels, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      dropdownColor: kSurface2,
      decoration: InputDecoration(
        filled: true,
        fillColor: kSurface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kBorder),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: items.asMap().entries.map((e) => DropdownMenuItem<T>(
        value: e.value,
        child: Text(labels != null ? labels![e.key] : e.value.toString()),
      )).toList(),
      onChanged: onChanged,
    );
  }
}
