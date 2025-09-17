import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/extensions/development_filter.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/components/drawer/drawer_panel.dart';
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

    Widget _buildContent(AsyncValue<Topology> topology, OnRetryCallback onRetry) {

    SideDrawer.logger.d("2 BuildContent called with topology=$topology");
    
    return 
      _buildDrawerPanel(topology, onRetry);
  }

    DrawerPanel _buildDrawerPanel(AsyncValue<Topology> topology, OnRetryCallback onRetry) {
    final selectedPanel = ref.watch(screenSelectionNotifier).selected;
    SideDrawer.logger.d("3 _buildDrawerPanel called, selectedPanel=$selectedPanel");
    
    return DrawerPanel(
      isVisible: ref.watch(drawerStateNotifier).isOpen,
      selectedPanel: selectedPanel,
      topology: topology,
      onRetry: onRetry,
    ) ;
  }

  @override
  Widget build(BuildContext context) {
    SideDrawer.logger.d("Triggered drawer rebuild");

    return Consumer(builder: 
      (context, ref, child) {
        var topology = ref.watch(topologyProvider);

        SideDrawer.logger.d("1 Triggered a drawer rebuild with topology=$topology");
        Future<void> onRetry() async => _onRetry();
        return _buildContent(topology, onRetry);
      }
    );
  }
}