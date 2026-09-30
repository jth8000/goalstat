import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/goal.dart';
import '../theme.dart';

/// Month calendar for picking a check-in day, with a check under each day in
/// [loggedDates] ('yyyy-MM-dd'). Future days can't be picked.
Future<DateTime?> showDayPicker(
  BuildContext context, {
  required DateTime initialDay,
  required Set<String> loggedDates,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: kSurface,
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // TableCalendar fills whatever height it's given, so fix it to
            // six week rows (header + weekday labels + 6 × rowHeight).
            SizedBox(
              height: 430,
              child: _DayPicker(initialDay: initialDay, loggedDates: loggedDates),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DayPicker extends StatefulWidget {
  final DateTime initialDay;
  final Set<String> loggedDates;

  const _DayPicker({required this.initialDay, required this.loggedDates});

  @override
  State<_DayPicker> createState() => _DayPickerState();
}

class _DayPickerState extends State<_DayPicker> {
  late DateTime _focused = widget.initialDay;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return TableCalendar<void>(
      firstDay: DateTime(2000),
      lastDay: today,
      focusedDay: _focused,
      startingDayOfWeek: StartingDayOfWeek.values[Goal.firstWeekday - 1],
      // Leave room under the day circle for the check mark.
      rowHeight: 56,
      sixWeekMonthsEnforced: true,
      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
      selectedDayPredicate: (d) => isSameDay(d, widget.initialDay),
      onDaySelected: (selected, _) => Navigator.pop(
          context, DateTime(selected.year, selected.month, selected.day)),
      onPageChanged: (focused) => _focused = focused,
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, _) => widget.loggedDates.contains(_fmt(day))
            ? const Positioned(
                bottom: 1,
                child: Icon(Icons.check, size: 12, color: kGreen),
              )
            : null,
      ),
      headerStyle: const HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false,
        titleTextStyle: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w600),
        leftChevronIcon: Icon(Icons.chevron_left, color: kText),
        rightChevronIcon: Icon(Icons.chevron_right, color: kText),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: kMuted, fontSize: 12),
        weekendStyle: TextStyle(color: kMuted, fontSize: 12),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        cellMargin: const EdgeInsets.fromLTRB(6, 4, 6, 14),
        defaultTextStyle: const TextStyle(color: kText),
        weekendTextStyle: const TextStyle(color: kText),
        disabledTextStyle: TextStyle(color: kMuted.withValues(alpha: 0.4)),
        todayTextStyle: const TextStyle(color: kPurple, fontWeight: FontWeight.bold),
        todayDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: kPurple),
        ),
        selectedTextStyle: const TextStyle(color: kBg, fontWeight: FontWeight.bold),
        selectedDecoration: const BoxDecoration(
          color: kPurple,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
