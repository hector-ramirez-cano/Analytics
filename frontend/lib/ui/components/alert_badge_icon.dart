import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/services/realtime/alerts_realtime_service.dart';
import 'package:network_analytics/ui/components/badge_icon.dart';

class AlertBadgeIcon extends StatelessWidget {
  const AlertBadgeIcon({super.key});
  
  Widget _buildNotificationBadgeIcon(WidgetRef ref) {
    String? badgeContent = "";
    int alertCount = 0;
    final unreadNotifications = ref.watch(alertsRealtimeServiceProvider);

    unreadNotifications.when(
      data: (unseenAlerts) => alertCount = unseenAlerts.unseenAlerts.length,
      error: (_ ,_) => badgeContent = "?",
      loading: () => badgeContent = "⧗",
    );

    if (alertCount == 0) { badgeContent = null; }
    else { 
      if (alertCount < 10) {
        badgeContent = alertCount.toString();
      }
      else {
        badgeContent = "9+";
      }
    }

    return BadgeIcon(
      icon: Icon(Icons.notifications, size: 32, color: Colors.white,),
      badgeContent: badgeContent,
      tooltip: "Notificaciones",
    );
  }
  
  @override
  Widget build(BuildContext context) {

    return Consumer(builder:(context, ref, child) => 
      IconButton(onPressed: () => {ref.read(alertsRealtimeServiceProvider.notifier).markAsSeen()}, icon: _buildNotificationBadgeIcon(ref))
    );
  }

}