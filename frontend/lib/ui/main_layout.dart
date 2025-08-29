import 'package:flutter/material.dart';
import 'package:network_analytics/ui/components/drawer/drawer.dart';
import 'package:network_analytics/ui/components/title_bar.dart';
import 'package:network_analytics/ui/screens/content_area.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // AppBar
          TitleBar(),

          // Main content row
          Expanded(
            child: Row(
              children: const [
                SideDrawer(),
                Expanded(child: ContentArea()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
