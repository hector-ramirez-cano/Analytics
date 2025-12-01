import 'package:aegis/models/device.dart';
import 'package:aegis/ui/components/backend_health_notification_item.dart';
import 'package:aegis/ui/components/measure_size.dart';
import 'package:aegis/ui/components/overlays/commons.dart';
import 'package:flutter/material.dart';


Widget _makeStatusDashboard(Device device) {
  if (device.statusMap == null) {
    return Text("No hay datos de estado.");
  }

  final statusMap = device.statusMap!;
  final children = statusMap.entries
  .where((status) => device.dataSources.contains(status.key) || status.value["status"] != "unknown")
  .map((status) => 
    BackendHealthNotificationItem(
        key: ValueKey("BackendHealth_Overlay_${status.key}_NotificationItem"),
        up: status.value["status"] == "reachable",
        message: "${status.value["msg"]}\nstatus = ${status.value["status"]}",
        which: status.key,
      )
  ).toList();
  
  return ListView(shrinkWrap: true,children: [
    Text("${device.name}@${device.mgmtHostname}"),
    Divider(),
    ...children
  ],);
}

Widget _makeHealthWidget(Device device) {
  return Material(
    color: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: _makeStatusDashboard(device),
    ),
  );
}

OverlayEntry showDeviceHealthOverlay(BuildContext context, Device device, Offset position) {
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;
  Size? measuredSize;

  overlayEntry = OverlayEntry(
    builder: (_) {
      // If we don't know the size yet -> place arbitrarily
      final size = measuredSize;

      double top = position.dy;
      double left = position.dx + 32;

      if (size != null) {
        final screen = MediaQuery.of(context).size;

        // auto-flip vertically
        if (screen.height - position.dy < size.height) {
          top = position.dy - size.height;
        }

        // prevent horizontal overflow
        if (position.dx + size.width > screen.width) {
          left = screen.width - size.width;
        }
      }

      return Positioned(
        top: top,
        left: left,
        child: MeasureSize(
          onChange: (s) {
            // when the size is known -> update overlay
            if (measuredSize != s) {
              measuredSize = s;
              overlayEntry.markNeedsBuild();
            }
          },
          child: makeNotificationWidget(context, _makeHealthWidget(device), shrinkWrap: true),
        ),
      );
    },
  );


  overlay.insert(overlayEntry);

  return overlayEntry;
}