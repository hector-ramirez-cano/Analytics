import 'package:aegis/ui/components/overlays/alert_listing_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aegis/services/realtime/alerts_realtime_service.dart';
import 'package:aegis/ui/components/badge_icon.dart';

class AlertBadgeIcon extends StatelessWidget {
  const AlertBadgeIcon({super.key});
  
  Widget _buildNotificationBadgeIcon(WidgetRef ref) {
    String? badgeContent = "";
    Color badgeColor = Colors.red;
    int alertCount = 0;
    final unreadNotifications = ref.watch(alertsRealtimeServiceProvider);

    unreadNotifications.when(
      error: (_ ,_) { badgeContent = "?"; badgeColor = Colors.blueGrey; },
      loading: () { badgeContent = "⧗"; badgeColor = Colors.blueGrey; },
      data: (unseenAlerts) {
        if (alertCount == 0) { badgeContent = null; }
        else { 
          if (alertCount < 10) {
            badgeContent = alertCount.toString();
          }
          else {
            badgeContent = "9+";
          }
        }
      },
    );

    cursor() => badgeContent == "⧗" ? SystemMouseCursors.progress :  SystemMouseCursors.click;

    return BadgeIcon(
      cursor: badgeContent != null ?  cursor : null,
      icon: Icon(Icons.notifications, size: 32, color: Colors.white,),
      badgeContent: badgeContent,
      badgeColor: badgeColor,
      tooltip: "Notificaciones",
    );
  }
  
  @override
  Widget build(BuildContext context) {

    return Consumer(builder:(context, ref, child) {
      bool available = ref.watch(alertsRealtimeServiceProvider).when(
        data: (_) => true,
        error: (_, _) => false,
        loading: () => false
      );

      onClick() {
        showAlertListingOverlay(context);
        ref.read(alertsRealtimeServiceProvider.notifier).markAsSeen();
      }

      return IconButton(
        onPressed: available ? onClick : null,
        mouseCursor: available ? SystemMouseCursors.click : SystemMouseCursors.progress,
        icon: _buildNotificationBadgeIcon(ref)
      );
    }
    );
  }

}