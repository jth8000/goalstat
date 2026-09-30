import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../models/goal.dart';
import '../models/period_status.dart';
import '../theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final _db = AppDatabase.instance;
  int _periodIdx = 0;
  List<Map<String, dynamic>> _entries = [];
  List<PeriodStatus> _statuses = [];
  bool _loading = false;

  static const _periods = ['This Week', 'This Month', 'Last 3 Months', 'All Time'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime, DateTime) _dateRange() {
    final today = DateTime.now();
    switch (_periodIdx) {
      case 0:
        return (Goal.weekStart(today), today);
      case 1:
        return (DateTime(today.year, today.month, 1), today);
      case 2:
        return (today.subtract(const Duration(days: 90)), today);
      default:
        return (DateTime(2000), today);
    }
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    final (start, end) = _dateRange();
    final entries = await _db.getAllEntries(_fmt(start), _fmt(end));
    final statuses = await _db.getEntryStatuses(entries);
    if (mounted) {
      setState(() { _entries = entries; _statuses = statuses; _loading = false; });
    }
  }

  String _formatValue(Map<String, dynamic> e) {
    final val = (e['value'] as num).toDouble();
    if (e['type'] == 'boolean') return val >= 1 ? 'Yes' : 'No';
    final unit = e['unit'] as String?;
    return '${val % 1 == 0 ? val.toInt() : val}${unit != null ? " $unit" : ""}';
  }

  Future<void> _export() async {
    final rows = <List<dynamic>>[
      ['Date', 'Goal', 'Category', 'Value', 'Unit', 'Evaluated', 'Status']
    ];
    for (final (i, e) in _entries.indexed) {
      rows.add([
        e['date'],
        e['name'],
        e['category'],
        e['value'],
        e['unit'] ?? '',
        e['eval_period'],
        _statuses[i],
      ]);
    }

    final csv = rows.map((r) => r.map((c) => '"$c"').join(',')).join('\n');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/goalstat_export.csv');
    await file.writeAsString(csv);

    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      text: 'GoalStat Export',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export CSV',
            onPressed: _export,
          ),
        ],
      ),
      body: Column(
        children: [
          _PeriodPicker(
            selected: _periodIdx,
            periods: _periods,
            onChanged: (i) { setState(() => _periodIdx = i); _load(); },
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? const Center(
                        child: Text('No entries for this period.',
                            style: TextStyle(color: kMuted)))
                    : _EntryTable(entries: _entries, statuses: _statuses,
                        formatValue: _formatValue),
          ),
        ],
      ),
    );
  }
}

class _PeriodPicker extends StatelessWidget {
  final int selected;
  final List<String> periods;
  final ValueChanged<int> onChanged;

  const _PeriodPicker({required this.selected, required this.periods,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kSurface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: periods.asMap().entries.map((e) {
          final selected_ = e.key == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected_ ? kPurple.withValues(alpha: 0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected_ ? kPurple : kBorder,
                  ),
                ),
                child: Text(
                  e.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected_ ? kPurple : kMuted,
                    fontSize: 12,
                    fontWeight: selected_ ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EntryTable extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final List<PeriodStatus> statuses;
  final String Function(Map<String, dynamic>) formatValue;

  const _EntryTable({required this.entries, required this.statuses,
      required this.formatValue});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: entries.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Container(
            color: kSurface2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Date', style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(flex: 3, child: Text('Goal', style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('Value', style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                SizedBox(width: 96, child: Text('Status', style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
              ],
            ),
          );
        }
        final e = entries[i - 1];
        final status = statuses[i - 1];
        final color = statusColor(status.level);
        return Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: kBorder.withValues(alpha: 0.4))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text(
                _shortDate(e['date'] as String),
                style: const TextStyle(color: kMuted, fontSize: 13),
              )),
              Expanded(flex: 3, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e['name'] as String,
                      style: const TextStyle(color: kText, fontSize: 13)),
                  if ((e['category'] as String).isNotEmpty)
                    Text(e['category'] as String,
                        style: const TextStyle(color: kMuted, fontSize: 11)),
                ],
              )),
              Expanded(flex: 2, child: Text(
                formatValue(e),
                textAlign: TextAlign.right,
                style: const TextStyle(color: kText, fontSize: 13),
              )),
              SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(status.label,
                        textAlign: TextAlign.right,
                        style: TextStyle(color: color, fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    if (status.detail != null)
                      Text(status.detail!,
                          textAlign: TextAlign.right,
                          style: TextStyle(color: color, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _shortDate(String iso) {
    final d = DateTime.parse(iso);
    return DateFormat('MMM d').format(d);
  }
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
