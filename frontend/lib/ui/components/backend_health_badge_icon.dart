import 'package:aegis/services/realtime/backend_health_service.dart';
import 'package:aegis/ui/components/overlays/backend_health_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aegis/ui/components/badge_icon.dart';

class BackendHealthBadgeIcon extends StatelessWidget {
  const BackendHealthBadgeIcon({super.key});
  
  Widget _buildNotificationBadgeIcon(WidgetRef ref) {
    String? badgeContent = "";
    Color badgeColor = Colors.redAccent;

    final healthStatus = ref.watch(backendHealthServiceProvider);

    healthStatus.when(
      error: (_ ,_) => badgeContent = "?",
      loading: () { badgeContent = "⧗"; badgeColor = Colors.blueGrey; } ,
      data: (status) {
        badgeContent = null;
      },
    );

    cursor() => badgeContent == "⧗" ? SystemMouseCursors.progress : SystemMouseCursors.click;

    return BadgeIcon(
      icon: Icon(Icons.monitor_heart_sharp, size: 32, color: Colors.white,),
      badgeContent: badgeContent,
      badgeColor: badgeColor,
      tooltip: "Salud del Backend",
      cursor: cursor
    );
  }
  
  @override
  Widget build(BuildContext context) {

    return Consumer(builder:(context, ref, child) => 
      IconButton(onPressed: () => showBackendHealthOverlay(context), icon: _buildNotificationBadgeIcon(ref))
    );
  }

}