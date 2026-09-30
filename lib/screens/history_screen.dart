import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _db = AppDatabase.instance;
  int _periodIdx = 0;
  List<Map<String, dynamic>> _entries = [];
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
        final mon = today.subtract(Duration(days: today.weekday - 1));
        return (DateTime(mon.year, mon.month, mon.day), today);
      case 1:
        return (DateTime(today.year, today.month, 1), today);
      case 2:
        return (today.subtract(const Duration(days: 90)), today);
      default:
        return (DateTime(2000), today);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (start, end) = _dateRange();
    final entries = await _db.getAllEntries(_fmt(start), _fmt(end));
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  bool _isOnTarget(Map<String, dynamic> e) {
    final val = (e['value'] as num).toDouble();
    final target = (e['target_value'] as num).toDouble();
    switch (e['target_direction'] as String) {
      case 'gte': return val >= target;
      case 'lte': return val <= target;
      default: return val == target;
    }
  }

  String _formatValue(Map<String, dynamic> e) {
    final val = (e['value'] as num).toDouble();
    if (e['type'] == 'boolean') return val >= 1 ? 'Yes' : 'No';
    final unit = e['unit'] as String?;
    return '${val % 1 == 0 ? val.toInt() : val}${unit != null ? " $unit" : ""}';
  }

  Future<void> _export() async {
    final (start, end) = _dateRange();
    final allEntries = await _db.getAllEntries(_fmt(start), _fmt(end));

    final rows = <List<dynamic>>[
      ['Date', 'Goal', 'Category', 'Value', 'Unit', 'On Target']
    ];
    for (final e in allEntries) {
      rows.add([
        e['date'],
        e['name'],
        e['category'],
        e['value'],
        e['unit'] ?? '',
        _isOnTarget(e) ? 'Yes' : 'No',
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
                    : _EntryTable(entries: _entries, isOnTarget: _isOnTarget,
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
  final bool Function(Map<String, dynamic>) isOnTarget;
  final String Function(Map<String, dynamic>) formatValue;

  const _EntryTable({required this.entries, required this.isOnTarget,
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
                SizedBox(width: 60, child: Text('Status', style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
              ],
            ),
          );
        }
        final e = entries[i - 1];
        final on = isOnTarget(e);
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
                width: 60,
                child: Text(
                  on ? 'On target' : 'Off',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: on ? kGreen : kRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
