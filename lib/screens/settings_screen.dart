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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goals = await _db.getGoals();
    if (mounted) setState(() { _goals = goals; _loading = false; });
  }

  List<String> get _categories =>
      _goals.map((g) => g.category).where((c) => c.isNotEmpty).toSet().toList()
        ..sort();

  void _add() async {
    final data = await showDialog<_GoalFormData>(
        context: context,
        builder: (_) => _GoalDialog(categories: _categories));
    if (data == null) return;
    await _db.addGoal(data.toGoal());
    _load();
    widget.onGoalsChanged();
  }

  void _edit(Goal g) async {
    final data = await showDialog<_GoalFormData>(
        context: context,
        builder: (_) => _GoalDialog(goal: g, categories: _categories));
    if (data == null) return;
    await _db.updateGoal(data.toGoal(id: g.id));
    _load();
    widget.onGoalsChanged();
  }

  void _delete(Goal g) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Delete "${g.name}"?\n\n'
            'All of its logged entries will be deleted too. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: kRed)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _db.deleteGoal(g.id!);
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
              ? const Center(child: Text('No goals yet. Tap + to add one.',
                  style: TextStyle(color: kMuted)))
              : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _goals.length,
              separatorBuilder: (context, idx) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _GoalTile(
                goal: _goals[i],
                onEdit: () => _edit(_goals[i]),
                onDelete: () => _delete(_goals[i]),
              ),
            ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final Goal goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalTile({required this.goal, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final g = goal;
    final period = g.evalPeriod[0].toUpperCase() + g.evalPeriod.substring(1);
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
                Text(g.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: kText,
                    )),
                const SizedBox(height: 4),
                Text(
                  '${g.category.isNotEmpty ? "${g.category}  ·  " : ""}${g.isBoolean ? "Yes/No" : "Number${g.unit != null ? " (${g.unit})" : ""}"}  ·  $period  ·  ${g.directionSymbol} ${g.targetValue % 1 == 0 ? g.targetValue.toInt() : g.targetValue}',
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
          IconButton(
            icon: const Icon(Icons.delete_outline, color: kRed, size: 20),
            onPressed: onDelete,
            tooltip: 'Delete',
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
  final String evalPeriod;
  final double targetValue;
  final String targetDirection;

  const _GoalFormData({
    required this.name,
    required this.category,
    required this.type,
    this.unit,
    required this.evalPeriod,
    required this.targetValue,
    required this.targetDirection,
  });

  Goal toGoal({int? id}) => Goal(
    id: id,
    name: name, category: category, type: type, unit: unit,
    evalPeriod: evalPeriod,
    targetValue: targetValue, targetDirection: targetDirection,
  );
}

class _GoalDialog extends StatefulWidget {
  final Goal? goal;
  final List<String> categories;
  const _GoalDialog({this.goal, this.categories = const []});

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  String _type = 'boolean';
  String _evalPeriod = 'daily';
  String _direction = 'gte';

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    if (g != null) {
      _nameCtrl.text = g.name;
      _categoryCtrl.text = g.category;
      _type = g.type;
      _unitCtrl.text = g.unit ?? '';
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
    _categoryCtrl.dispose();
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
    // Reuse an existing category's spelling so "fitness" groups with "Fitness".
    final typed = _categoryCtrl.text.trim();
    final category = widget.categories.firstWhere(
        (c) => c.toLowerCase() == typed.toLowerCase(), orElse: () => typed);
    Navigator.pop(context, _GoalFormData(
      name: _nameCtrl.text.trim(),
      category: category,
      type: _type,
      unit: _type == 'boolean' ? null : unit,
      evalPeriod: _evalPeriod,
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
            _field('Category (optional)', _CategoryField(
              controller: _categoryCtrl,
              categories: widget.categories,
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
            _field('Evaluate', _DropdownField<String>(
              value: _evalPeriod,
              items: const ['daily', 'weekly', 'monthly'],
              labels: const ['Daily', 'Weekly', 'Monthly'],
              onChanged: (v) => setState(() => _evalPeriod = v!),
            )),
            _field('Direction', _DropdownField<String>(
              value: _direction,
              items: const ['gte', 'lte', 'eq'],
              labels: const ['≥  at least', '≤  at most', '=  exactly'],
              onChanged: (v) => setState(() => _direction = v!),
            )),
            _field(_evalPeriod == 'daily'
                ? 'Target'
                : 'Target (total per ${_evalPeriod == 'weekly' ? 'week' : 'month'})',
                TextField(
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

class _CategoryField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> categories;

  const _CategoryField({required this.controller, required this.categories});

  @override
  State<_CategoryField> createState() => _CategoryFieldState();
}

class _CategoryFieldState extends State<_CategoryField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        return widget.categories.where((c) =>
            c.toLowerCase().contains(q) && c.toLowerCase() != q);
      },
      fieldViewBuilder: (context, ctrl, focusNode, onSubmitted) => TextField(
        controller: ctrl,
        focusNode: focusNode,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'e.g. Fitness'),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: kSurface2,
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 240),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: options.map((c) => ListTile(
                dense: true,
                title: Text(c),
                onTap: () => onSelected(c),
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }
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
