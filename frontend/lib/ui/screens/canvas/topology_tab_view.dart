import 'package:flutter/material.dart';
import 'package:network_analytics/ui/components/chip_tab_bar.dart';
import 'package:network_analytics/ui/screens/canvas/topology_canvas.dart';

class TopologyTabView extends StatelessWidget {
  const TopologyTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox.fromSize(
          size: Size(double.infinity, 40),
          child: ChipTabBar()
        ),
        Expanded(
          child: TopologyCanvas()
        )
        
      ],
    );
  }
}