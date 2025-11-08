import 'package:aegis/services/realtime/alerts_realtime_service.dart';
import 'package:aegis/ui/components/overlays/commons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Widget _makeAlertEntry(BuildContext context, int index, UnseenAlerts unseenAlerts) {
  final alert = unseenAlerts.unseenAlerts[index];
  return Row(
    children: [
      TweenAnimationBuilder<Color?>(
        tween: ColorTween(begin: Colors.green, end: const Color.fromARGB(0, 76, 175, 79)),
        duration: const Duration(seconds: 5),
        builder: (context, color, child) {
          return Text("•", style: TextStyle(color: color),);
        }
      ),
      Container(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: EdgeInsets.all(12),
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
        child: Text(
          "${alert.alertTime.toString()} ${alert.message}",
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
      )

    ],
  );
}

Widget _makeAlertEntries(WidgetRef ref) {
  final unreadNotifications = ref.read(alertsRealtimeServiceProvider);

  return unreadNotifications.when(
    error: (_, _) => Center(child: Text("Se produjo un error...")),
    loading: () => Center(child: CircularProgressIndicator.adaptive()),
    data: (unseenAlerts) {
      if (unseenAlerts.unseenAlerts.isEmpty) {
        return Center(child: Text("No hay alertas nuevas"));
      }

      return ListView.builder(itemBuilder: (context, index) => _makeAlertEntry(context, index, unseenAlerts));
    },
  );
}

void showAlertListingOverlay(BuildContext context) {
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
          child: makeNotificationWidget(_makeAlertEntries(ref)) ,
      ),
      ],)
    )
  );

  overlay.insert(overlayEntry);

}