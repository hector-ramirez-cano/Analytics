

import 'dart:async';

import 'package:aegis/services/realtime/alerts_realtime_service.dart';
import 'package:aegis/ui/components/alert_notification_item.dart';
import 'package:aegis/ui/components/overlays/commons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:implicitly_animated_list/implicitly_animated_list.dart';

const Duration seenDuration = Duration(seconds: 5);

Widget _makeAlertEntry(BuildContext context, AlertOverlayDetails details) {
  return AlertNotificationItem(event: details.event, seen: details.seen, initialExpanded: details.expanded, key: GlobalKey(),);
}

Widget _makeAlertEntries(WidgetRef ref) {
  final unreadNotifications = ref.watch(alertsRealtimeServiceProvider);

  return unreadNotifications.when(
    error: (_, _) => Center(child: Text("Se produjo un error...")),
    loading: () => Center(child: CircularProgressIndicator.adaptive()),
    data: (unseenAlerts) {
      if (unseenAlerts.alerts.isEmpty) {
        return Center(child: Text("No hay alertas nuevas"));
      }

      final _ = Timer(seenDuration, () {
        if (ref.context.mounted) {
          ref.read(alertsRealtimeServiceProvider.notifier).markAsSeen();
        }
      });
      return ImplicitlyAnimatedList<AlertOverlayDetails>(
        key: const ValueKey("Alerts_Overlay_Notification_AnimatedList"),
        itemData: unseenAlerts.alerts.reversed.toList(),
        itemEquality: (a, b) => a.event.id == b.event.id,
        itemBuilder: (context, data) {
          return _makeAlertEntry(context, data);
        },
      );
    },
  );
}

void showAlertListingOverlay(BuildContext context) {
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => Consumer(
      key: ValueKey("Alert_Overlay_Consumer"),
      builder: (context, ref, child) 
      => Stack(
        key: ValueKey("Alert_Overlay_Stack"),
        children: [
        Positioned.fill(child: Consumer(builder:(context, ref, child) {
          return GestureDetector(
            onTap: () { 
              overlayEntry.remove();
              ref.read(alertsRealtimeServiceProvider.notifier).markAsSeen();
            },
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          );
        },)),
        Positioned(
          key: ValueKey("Alert_Overlay_PositionedWidget"),
          right: 16,
          top: 64,
          child: makeNotificationWidget(context, _makeAlertEntries(ref)) ,
      ),
      ],)
    )
  );

  overlay.insert(overlayEntry);

}