import 'package:flutter/material.dart';
import 'package:network_analytics/theme/app_colors.dart';
import 'package:network_analytics/ui/components/alert_badge_icon.dart';
import 'package:network_analytics/ui/screens/content_body.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});


  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analytics", style: TextStyle(color: AppColors.appBarTitleColor),),
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.appBarColor,
        actions: [
          AlertBadgeIcon()
        ],
      ),
      body: ContentBody()
    );
  }
}
