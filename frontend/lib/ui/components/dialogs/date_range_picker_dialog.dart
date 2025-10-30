import 'package:flutter/material.dart';
import 'package:aegis/ui/components/date_range_picker.dart';

/// Shows a dialog for selecting a date range with optional start/end times.
Future<DateTimeRange?> showDateRangeWithTimeDialog(BuildContext context) async {
  DateTimeRange? selectedRange;
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  return showDialog<DateTimeRange>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          void selectPreset(String preset) {
            final now = DateTime.now();
            DateTimeRange range;
            switch (preset) {
              case 'Today':
                range = DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now);
                break;
              case 'Last 7 Days':
                range = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
                break;
              case 'Last 30 Days':
                range = DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
                break;
              default:
                return;
            }
            setState(() {
              selectedRange = range;
              startTime = TimeOfDay.fromDateTime(range.start);
              endTime = TimeOfDay.fromDateTime(range.end);
            });
          }

          Future<void> pickCustomRange() async {
            final now = DateTime.now();
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 5),
              initialDateRange: selectedRange,
            );
            if (picked == null) return;

            if (!context.mounted) {return;}
            final sTime = await showTimePicker(
              context: context,
              initialTime: startTime ?? TimeOfDay.fromDateTime(picked.start),
            );
            if (sTime == null) return;

            if (!context.mounted) {return;}
            final eTime = await showTimePicker(
              context: context,
              initialTime: endTime ?? TimeOfDay.fromDateTime(picked.end),
            );
            if (eTime == null) return;

            final combinedStart = DateTime(
              picked.start.year,
              picked.start.month,
              picked.start.day,
              sTime.hour,
              sTime.minute,
            );
            final combinedEnd = DateTime(
              picked.end.year,
              picked.end.month,
              picked.end.day,
              eTime.hour,
              eTime.minute,
            );

            // Validate
            if (!context.mounted) {return;}
            if (combinedStart.isAfter(combinedEnd)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Start date/time must be before end date/time')),
              );
              return;
            }

            setState(() {
              selectedRange = DateTimeRange(start: combinedStart, end: combinedEnd);
              startTime = sTime;
              endTime = eTime;
            });
          }

          String localFormatRange() {
            if (selectedRange == null) return '--';
            return formatRange(selectedRange);
          }

          return AlertDialog(
            title: const Text('Selecciona un rango'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ActionChip(label: const Text('Hoy'), onPressed: () => selectPreset('Today')),
                    ActionChip(label: const Text('Últimos 7 días'), onPressed: () => selectPreset('Last 7 Days')),
                    ActionChip(label: const Text('Últimos 30 días'), onPressed: () => selectPreset('Last 30 Days')),
                    ActionChip(label: const Text('Personalizado'), onPressed: pickCustomRange),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 500,
                  child: Row(
                    children: [
                      Expanded(
                        child: Card(
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                const Icon(Icons.date_range, size: 20, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(child: Text(localFormatRange(), style: const TextStyle(fontSize: 16))),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete), 
                        onPressed: selectedRange == null ? null : () {
                          setState(() {
                            selectedRange = null;
                            startTime = null;
                            endTime = null;
                          });
                        },
                      )
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: selectedRange == null
                    ? null
                    : () => Navigator.of(context).pop(selectedRange),
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      );
    },
  );
}
