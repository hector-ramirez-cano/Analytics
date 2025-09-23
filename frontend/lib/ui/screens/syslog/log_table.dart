import 'package:flutter/material.dart';
import 'package:network_analytics/ui/components/date_range_picker.dart';

class LogTable extends StatelessWidget {

  Widget _makeDeviceSelection() {
    return 
  }

  Widget _makeDateRangePicker() {
    return DatePicker();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _makeDateRangePicker(),
    ],);
  }

}