import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/extensions/development_filter.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/ui/components/drawer/item_edit_panel.dart';
import 'package:network_analytics/ui/components/drawer/listing_panel.dart';
import 'package:network_analytics/ui/components/enums/navigation_rail_item.dart';
import 'package:network_analytics/ui/components/retry_indicator.dart';

class DrawerPanel extends StatelessWidget {
  final bool isVisible;
  final NavigationRailItem? selectedPanel;
  final AsyncValue<Topology> topology;
  final OnRetryCallback onRetry;

  static Logger logger = Logger(filter: ConfigFilter.fromConfig("debug/enable_drawer_logging", false));

  const DrawerPanel({
    super.key,
    required this.isVisible,
    required this.selectedPanel,
    required this.topology,
    required this.onRetry
  });


  Widget _buildOnNotSuccessful(String? error, bool isLoading) {
    return Center(
      child: RetryIndicator(onRetry: onRetry, error: error, isLoading: isLoading,),
    );
    
  }

  Widget createContainerFromSelection(AsyncValue<Topology> topology) {
    logger.d("5 Creating drawer panel from $selectedPanel, topology=$topology");

    // TODO: Handle on at least one successful load, don't completely change the layout to a error layout if it fails
    switch (selectedPanel) {
      case NavigationRailItem.canvas:
        return topology.when(
          data   : (topology)  => ListingPanel(topology: topology),
          error  : (error, st) => _buildOnNotSuccessful(error.toString(), topology.isLoading),
          loading: ()          => _buildOnNotSuccessful(null, true)
        );

      case NavigationRailItem.charts:
        return topology.when(
          data   : (topology)  => ListingPanel(topology: topology),
          error  : (error, st) => _buildOnNotSuccessful(error.toString(), topology.isLoading),
          loading: ()          => _buildOnNotSuccessful(null, true)
        );

      case NavigationRailItem.edit:
        return topology.when(
          data   : (topology) => ItemEditPanel(topology: topology),
          error  : (error, st) => _buildOnNotSuccessful(error.toString(), topology.isLoading),
          loading: ()          => _buildOnNotSuccessful(null, true)
        );


      default:
        if (selectedPanel?.hasDrawer == true) {
          logger.w("Creating drawer panel with default text");
          return Text("No one here but us chickens!");
        } else {
          logger.w("Creating drawer panel for side-nav menu which specified hasDrawer=false!");
          return Text("ERROR, this panel doesn't have a drawer!");
        }

    }
  }

  @override
  Widget build(BuildContext context) {
    if (selectedPanel?.hasDrawer == false) {
      // force hiding of drawer
      return SizedBox.shrink();
    }
    logger.d("Building Panel...");
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.topLeft,
      child: createContainerFromSelection(topology)
    );
  }


}
