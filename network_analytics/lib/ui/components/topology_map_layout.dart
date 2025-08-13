import 'package:flutter/material.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/ui/components/drawer.dart';
import 'package:network_analytics/theme/app_colors.dart';
import 'title_bar.dart';

class TopologyMapLayout extends StatefulWidget {
  const TopologyMapLayout({super.key});

  @override
  State<TopologyMapLayout> createState() => _TopologyMapLayoutState();
}

class _TopologyMapLayoutState extends State<TopologyMapLayout> with TickerProviderStateMixin {
  Topology? topology;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          const TitleBar(),
          SideDrawer(),
        ],
      ),
    );
  }
}
