import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/ui/components/drawer/device_listing_panel.dart';
import 'package:network_analytics/ui/components/drawer/side_nav_item.dart';
import 'package:network_analytics/ui/components/retry_indicator.dart';

class DrawerPanel extends StatelessWidget {
  final double width;
  final bool isVisible;
  final Animation<double> fadeAnimation;
  final SideNavItem? selectedPanel;
  final AsyncValue<Topology> topology;
  final OnRetryCallback onRetry;

  const DrawerPanel({
    super.key,
    required this.width,
    required this.isVisible,
    required this.fadeAnimation,
    required this.selectedPanel,
    required this.topology,
    required this.onRetry
  });

  Widget createListingPanel(Topology? topology) {
    return CollapsibleSection.createCollapsibleSections(topology!.groups);
  }

  Widget _buildOnNotSuccessful(String? error, bool isLoading) {
    return Center(
      child: RetryIndicator(onRetry: onRetry, error: error, isLoading: isLoading,),
    );
    
  }

  Widget createContainerFromSelection(AsyncValue<Topology> topology) {
    Logger().d("5 Creating drawer panel from $selectedPanel, topology=$topology");
    switch (selectedPanel) {
      case SideNavItem.listado:
        return topology.when(
          data   : (topology)  => createListingPanel(topology),
          error  : (error, st) => _buildOnNotSuccessful(error.toString(), topology.isLoading),
          loading: ()          => _buildOnNotSuccessful(null, true)
        );

      default:
        return Text("No one here but us chickens!");

    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: isVisible
          ? FadeTransition(
              opacity: fadeAnimation,
              child: Container(
                color: Colors.grey.shade300,
                padding: const EdgeInsets.all(16),
                alignment: Alignment.topLeft,
                child: createContainerFromSelection(topology)
              ),
            )
          : const SizedBox.shrink(),
    );
  }


}
