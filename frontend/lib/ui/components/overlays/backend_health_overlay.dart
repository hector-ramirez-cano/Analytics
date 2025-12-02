import 'package:aegis/services/realtime/backend_health_service.dart';
import 'package:aegis/ui/components/backend_health_notification_item.dart';
import 'package:aegis/ui/components/overlays/commons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


Widget _makeStatusDashboard(WidgetRef ref) {
  final unreadNotifications = ref.read(backendHealthServiceProvider);

  return unreadNotifications.when(
    error: (_, _) => Center(child: Text("Se produjo un error...")),
    loading: () => Center(child: CircularProgressIndicator.adaptive()),
    data: (status) {
      return ListView(children: [
        BackendHealthNotificationItem(
          key: ValueKey("BackendHealth_Overlay_Postgres_NotificationItem"),
          up: status.postgresStatus,
          message: status.postgresMsg,
          which: "Postgres",
        ),
        BackendHealthNotificationItem(
          key: ValueKey("BackendHealth_Overlay_Influx_NotificationItem"),
          up: status.influxStatus,
          message: status.influxMsg,
          which: "InfluxDB",
        ),
        BackendHealthNotificationItem(
          key: ValueKey("BackendHealth_Overlay_Telegram_NotificationItem"),
          up: status.telegramEnabled,
          message: "En configuración",
          which: "Telegram",
        ),
        BackendHealthNotificationItem(
          key: ValueKey("BackendHealth_Overlay_Backend_NotificationItem"),
          up: status.backendConfigurable,
          message: "Estado de bloqueo definido en configuración",
          which: "Backend",
          downIcon: "🔐",
          upIcon: "🔓",
        ),
      ]);
    },
  );
}

Widget _makeHealthWidget(WidgetRef ref) {
  return Material(
    color: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: _makeStatusDashboard(ref),
    ),
  );
}

void showBackendHealthOverlay(BuildContext context) {
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => Consumer(builder: (context, ref, child)
      => Stack(children: [
        Positioned.fill(child: GestureDetector(
            onTap: () => overlayEntry.remove(),
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          )),
        Positioned(
          right: 16,
          top: 64,
          child: makeNotificationWidget(context, _makeHealthWidget(ref)) ,
      ),
      ],)
    )
  );

  overlay.insert(overlayEntry);

}