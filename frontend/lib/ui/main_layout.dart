import 'package:flutter/material.dart';
import 'package:network_analytics/ui/components/badge_icon.dart';
import 'package:network_analytics/ui/screens/content_body.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analytics"),
        automaticallyImplyLeading: false,
        actions: [
          BadgeIcon(icon: Icon(Icons.notifications, size: 32,), badgeContent: "1", tooltip: "Notificaciones",)
        ],
      ),
      body: ContentBody()
    );
  }
}
