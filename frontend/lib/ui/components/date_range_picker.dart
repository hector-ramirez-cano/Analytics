import 'package:flutter/material.dart';
import 'package:aegis/ui/components/dialogs/date_range_picker_dialog.dart';

String _formatTimeOfDay(DateTime dt) {
  final String hour = dt.hour < 10 ? "0${dt.hour}" : "${dt.hour}";
  final String minute = dt.minute < 10 ? "0${dt.minute}" : "${dt.minute}";

  return "$hour : $minute";
}

String _formatDate(DateTime dt) {
  const months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];
  return "${dt.day} / ${months[dt.month-1]} / ${dt.year}  ${_formatTimeOfDay(dt)}";
}

String formatRange(DateTimeRange? range) {
  if (range == null) return '--';
  return '${_formatDate(range.start)}   ⟶   ${_formatDate(range.end)}';
}

/// A widget that displays a selected date range and opens a dialog on tap.
class DateRangePicker extends StatefulWidget {
  /// Initial value, optional.
  final DateTimeRange? initialRange;

  /// Called when a new range is selected.
  final void Function(DateTimeRange)? onChanged;

  const DateRangePicker({super.key, this.initialRange, this.onChanged});

  @override
  State<DateRangePicker> createState() => _DateRangePickerState();
}

class _DateRangePickerState extends State<DateRangePicker> {
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
  }

  Future<void> _pickRange() async {
    final selectedRange = await showDateRangeWithTimeDialog(context);
    if (selectedRange == null) return;

    setState(() => _range = selectedRange);
    widget.onChanged?.call(selectedRange);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pickRange,
      child: ElevatedButton.icon(
        onPressed: _pickRange,
        label: Text(formatRange(_range), style: const TextStyle(fontSize: 16)),
        icon: const Icon(Icons.date_range, color: Colors.blue),
      ),
    );
  }
}
