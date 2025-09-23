import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/extensions/development_filter.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/services/screen_selection_notifier.dart';
import 'package:network_analytics/ui/components/drawer/item_edit_drawer.dart';
import 'package:network_analytics/ui/components/drawer/listing_drawer.dart';
import 'package:network_analytics/ui/components/enums/navigation_rail_item.dart';
import 'package:network_analytics/ui/components/retry_indicator.dart';

class SideDrawer extends ConsumerStatefulWidget{
  static Logger logger = Logger(filter: ConfigFilter.fromConfig("debug/enable_drawer_logging", false));

  const SideDrawer({super.key});

  @override
  ConsumerState<SideDrawer> createState() => _SideDrawerState();
}

class _SideDrawerState extends ConsumerState<SideDrawer> {

  void _onRetry() {
    var _ = ref.refresh(topologyProvider.future);
  }

  Widget _buildContent(AsyncValue<Topology> topology) {

    SideDrawer.logger.d("2 BuildContent called with topology=$topology");
    
    return _buildDrawerPanel(topology);
  }

  Widget _buildDrawerPanel(AsyncValue<Topology> topology) {
    final selectedPanel = ref.watch(sideNavSelectionProvider);
    SideDrawer.logger.d("3 _buildDrawerPanel called, selectedPanel=$selectedPanel");
    
    return _makeSelector(topology, selectedPanel);
  }

  Widget _buildOnNotSuccessful(String? error, bool isLoading) {
    return Center(
      child: RetryIndicator(onRetry: () async => _onRetry(), error: error, isLoading: isLoading,),
    );
    
  }

  Widget createContainerFromSelection(AsyncValue<Topology> topology, NavigationRailItem? selectedPanel) {
    SideDrawer.logger.d("5 Creating drawer panel from $selectedPanel, topology=$topology");

    // TODO: Handle on at least one successful load, don't completely change the layout to a error layout if it fails
    switch (selectedPanel) {
      case NavigationRailItem.canvas:
        return topology.when(
          data   : (topology)  => ListingDrawer(topology: topology),
          error  : (error, st) => _buildOnNotSuccessful(error.toString(), topology.isLoading),
          loading: ()          => _buildOnNotSuccessful(null, true)
        );

      case NavigationRailItem.charts:
        return topology.when(
          data   : (topology)  => ListingDrawer(topology: topology),
          error  : (error, st) => _buildOnNotSuccessful(error.toString(), topology.isLoading),
          loading: ()          => _buildOnNotSuccessful(null, true)
        );

      case NavigationRailItem.edit:
        return topology.when(
          data   : (topology) => ItemEditDrawer(topology: topology),
          error  : (error, st) => _buildOnNotSuccessful(error.toString(), topology.isLoading),
          loading: ()          => _buildOnNotSuccessful(null, true)
        );


      default:
        if (selectedPanel?.hasDrawer == true) {
          SideDrawer.logger.w("Creating drawer panel with default text");
          return Text("No one here but us chickens!");
        } else {
          SideDrawer.logger.w("Creating drawer panel for side-nav menu which specified hasDrawer=false!");
          return Text("ERROR, this panel doesn't have a drawer!");
        }

    }
  }

  Widget _makeSelector(AsyncValue<Topology> topology, NavigationRailItem? selectedPanel) { 
    if (selectedPanel?.hasDrawer == false) {
      // force hiding of drawer
      return SizedBox.shrink();
    }
    SideDrawer.logger.d("Building Panel...");
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.topLeft,
      child: createContainerFromSelection(topology, selectedPanel)
    );
  }

  @override
  Widget build(BuildContext context) {
    SideDrawer.logger.d("Triggered drawer rebuild");

    return Consumer(builder: 
      (context, ref, child) {
        var topology = ref.watch(topologyProvider);

        SideDrawer.logger.d("1 Triggered a drawer rebuild with topology=$topology");
        return _buildContent(topology);
      }
    );
  }
}