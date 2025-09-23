import 'package:flutter/material.dart';

class DatePicker extends StatefulWidget {
  const DatePicker({
    super.key,
    this.leading,
    this.trailing,
  });
  final Widget? leading;
  final Widget? trailing;

  @override
  State<DatePicker> createState() => _DatePickerState();
}

class _DatePickerState extends State<DatePicker> {
  late DateTimeRange _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _selectedDateRange = DateTimeRange(start: DateTime.now(), end: DateTime.now());
  }

  String _timeOfDateString(DateTime dt) {
    final String hour = dt.hour < 10 ? "0${dt.hour}" : "${dt.hour}";
    final String minute = dt.minute < 10 ? "0${dt.minute}" : "${dt.minute}";

    return "$hour : $minute";
  }

  String _dateString(DateTime dt) {
    const months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];
    return "${dt.day} / ${months[dt.month-1]} / ${dt.year}     ${_timeOfDateString(dt)}";
  }

  Future _selectDateRange(BuildContext context) async => showDateRangePicker(
    context: context,
    initialDateRange: _selectedDateRange,
    firstDate: DateTime(2000),
    lastDate: DateTime(2050),
    saveText: "Siguiente",
    cancelText: "Cancelar",
    helpText: "Rango de fechas",
  ).then((range) => {
    if (range != null && context.mounted) {
      _selectStartHour(context, range)
    }
  });

  Future _selectStartHour(BuildContext context, DateTimeRange range) => showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(range.start),
    helpText: "Hora de inicio",
    confirmText: "Siguiente",
    cancelText: "Cancelar"
  ).then((start) => {
    if (start != null && context.mounted) {
      _selectEndHour(context, range, start)
    }
  });

  Future _selectEndHour(BuildContext context, DateTimeRange range, TimeOfDay startTime) => showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(range.end),
    helpText: "Hora de fin",
    confirmText: "Aplicar",
    cancelText: "Cancelar"
  ).then((end) => {
    if (end != null) {
      setState(() {
        _selectedDateRange = DateTimeRange(
          start: range.start.copyWith(hour: startTime.hour, minute: startTime.minute),
          end: range.end.copyWith(hour: end.hour, minute: end.minute),
        );
      })
    }
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton(
          onPressed: () => _selectDateRange(context),
          child: Text(_dateString(_selectedDateRange.start)),
        ),
        SizedBox(width: 20,),
        Text(" —— "),
        SizedBox(width: 20,),
        ElevatedButton(
          onPressed: () => _selectDateRange(context),
          child: Text(_dateString(_selectedDateRange.end)),
        ),
      ],
    );
  }
}