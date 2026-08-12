import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateRangePickerWidget extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTimeRange> onSelected;

  const DateRangePickerWidget({
    super.key,
    this.startDate,
    this.endDate,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final displayText = startDate != null && endDate != null
        ? '${dateFormat.format(startDate!)} - ${dateFormat.format(endDate!)}'
        : 'Select Date Range';

    return InkWell(
      onTap: () async {
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: startDate != null && endDate != null
              ? DateTimeRange(start: startDate!, end: endDate!)
              : null,
        );
        if (range != null) {
          onSelected(range);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range, size: 20, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Text(displayText, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Icon(Icons.chevron_right, size: 20, color: Theme.of(context).textTheme.bodySmall?.color),
          ],
        ),
      ),
    );
  }
}

class MonthPickerWidget extends StatelessWidget {
  final int selectedMonth;
  final int selectedYear;
  final ValueChanged<DateTime> onSelected;

  const MonthPickerWidget({
    super.key,
    required this.selectedMonth,
    required this.selectedYear,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(selectedYear, selectedMonth),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          onSelected(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 20, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Text(
              '${months[selectedMonth - 1]} $selectedYear',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            Icon(Icons.chevron_right, size: 20, color: Theme.of(context).textTheme.bodySmall?.color),
          ],
        ),
      ),
    );
  }
}
