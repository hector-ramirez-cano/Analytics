import 'package:aegis/services/realtime/alerts_realtime_service.dart';
import 'package:aegis/ui/components/overlays/commons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


Widget _makeStatusDashboard(WidgetRef ref) {
  final unreadNotifications = ref.read(alertsRealtimeServiceProvider);

  return unreadNotifications.when(
    error: (_, _) => Center(child: Text("Se produjo un error...")),
    loading: () => Center(child: CircularProgressIndicator.adaptive()),
    data: (unseenAlerts) {
      if (unseenAlerts.unseenAlerts.isEmpty) {
        return Center(child: Text("No hay alertas nuevas"));
      }
      return SizedBox.shrink();
      // return ListView.builder(itemBuilder: (context, index) => /*TODO: This thing*/);
    },
  );
}

Widget _makeHealthWidget(WidgetRef ref) {
  return Material(
    color: Colors.transparent,
    child: Container(
      width: 400,
      height: 400,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
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
          child: makeNotificationWidget(_makeHealthWidget(ref)) ,
      ),
      ],)
    )
  );

  overlay.insert(overlayEntry);

}