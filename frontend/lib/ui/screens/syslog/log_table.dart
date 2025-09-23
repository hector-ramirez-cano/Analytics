import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/dialog_change_notifier.dart';
import 'package:network_analytics/services/syslog_device_filter_notifier.dart';
import 'package:network_analytics/ui/components/date_range_picker.dart';
import 'package:network_analytics/ui/components/dialogs/device_selection_dialog.dart';
import 'package:network_analytics/ui/components/list_selector.dart';

class LogTable extends StatelessWidget {

  final Topology topology;

  const LogTable({
    super.key,
    required this.topology,
  });

  Widget _makeDeviceSelection(WidgetRef ref, BuildContext context) {
    
    onSelect(device, state) {
      final notif = ref.watch(syslogDeviceFilterProvider.notifier);
      if (state == true) {
        notif.add(device);
      } else if (state == false) {
        notif.remove(device);
      }
      ref.read(dialogRebuildProvider.notifier).markDirty();
      
    }
    onClose() => {};

    isSelectedFn(device) {
      return ref.read(syslogDeviceFilterProvider).contains(device);
    }

    var dialog = DeviceSelectionDialog(
      options: topology.devices.toSet(),
      onChanged: onSelect,
      onClose: onClose,
      selectorType: ListSelectorType.checkbox,
      isSelectedFn: isSelectedFn,
    );

    return ElevatedButton(
      onPressed: () => dialog.show(context),
      child: Text("Seleccionar dispositivo")
    );
  }

  Widget _makeDateRangePicker(WidgetRef ref, BuildContext context) {
    return DatePicker(leading: _makeDeviceSelection(ref, context),);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder:(context, ref, child) => 
      Column(children: [
        _makeDateRangePicker(ref, context),
      ],)
    );
  }

}