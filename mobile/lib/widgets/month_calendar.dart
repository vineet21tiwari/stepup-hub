import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme.dart';

/// Month-grid calendar that highlights days containing at least one item (a class) — mirrors the
/// web's `MonthCalendar.jsx`. Wraps `table_calendar` instead of hand-rolling a grid.
class MonthCalendarWidget extends StatefulWidget {
  final List<dynamic> items;
  final String dateField;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  const MonthCalendarWidget({
    super.key,
    required this.items,
    required this.selectedDate,
    required this.onSelectDate,
    this.dateField = 'scheduledStart',
  });

  @override
  State<MonthCalendarWidget> createState() => _MonthCalendarWidgetState();
}

class _MonthCalendarWidgetState extends State<MonthCalendarWidget> {
  late DateTime _focusedDay = widget.selectedDate;

  List<dynamic> _eventsFor(DateTime day) {
    return widget.items.where((i) {
      final d = DateTime.parse(i[widget.dateField]).toLocal();
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2023, 1, 1),
        lastDay: DateTime.utc(2035, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (d) => _sameDay(d, widget.selectedDate),
        eventLoader: _eventsFor,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.grey),
          weekendStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.grey),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: true,
          todayDecoration: BoxDecoration(border: Border.all(color: cs.primary, width: 1.4), shape: BoxShape.circle),
          todayTextStyle: TextStyle(color: cs.primary, fontWeight: FontWeight.w800),
          selectedDecoration: const BoxDecoration(gradient: kAccentGradient, shape: BoxShape.circle),
          selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          markerDecoration: const BoxDecoration(color: kOrange, shape: BoxShape.circle),
          markersMaxCount: 1,
        ),
        onDaySelected: (selected, focused) {
          setState(() => _focusedDay = focused);
          widget.onSelectDate(selected);
        },
        onPageChanged: (focused) => _focusedDay = focused,
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
