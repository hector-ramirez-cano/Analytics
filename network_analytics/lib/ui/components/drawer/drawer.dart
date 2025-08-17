import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: unused_import
import 'package:logger/web.dart';

import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/components/drawer/side_nav_item.dart';
import 'package:network_analytics/ui/components/retry_indicator.dart';
import 'package:network_analytics/ui/components/side_nav.dart';
import 'package:network_analytics/ui/components/content_area.dart';
import 'package:network_analytics/ui/components/drawer/drawer_panel.dart';

class SideDrawer extends StatefulWidget {
  const SideDrawer({super.key});

  @override
  State<SideDrawer> createState() => _DrawerState();
}

class _DrawerState extends State<SideDrawer> with TickerProviderStateMixin {
  SideNavItem? selectedPanel;
  Topology? topology;

  final double drawerTargetWidth = 250;
  late final AnimationController _drawerController;
  late final Animation<double> _drawerWidth;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _drawerWidth = Tween<double>(begin: 0, end: drawerTargetWidth)
        .animate(CurvedAnimation(parent: _drawerController, curve: Curves.easeInOut));

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _drawerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _fadeController.forward();
      } else if (status == AnimationStatus.reverse) {
        _fadeController.reset();
      }
    });
  }

  void _handleNavClick(SideNavItem clickedItem) {
    if (selectedPanel == clickedItem) {
      _drawerController.reverse();
      setState(() {
        selectedPanel = null;
      });
    } else {
      setState(() {
        selectedPanel = clickedItem;
      });
      _drawerController.forward();
    }
  }

  SideNav _buildSideNav() {
    return SideNav(
      selectedPanel: selectedPanel,
      onPressed: _handleNavClick,
    );
  }

  AnimatedBuilder _buildDrawerPanel(AsyncValue<Topology> topology, OnRetryCallback onRetry) {
    // Logger().d("3 _buildDrawerPanel called, selectedPanel=$selectedPanel, status=${_drawerController.status}");
    bool isVisible = selectedPanel != null && (_drawerController.status == AnimationStatus.completed || _drawerController.isAnimating);
    
    return AnimatedBuilder(
      animation: _drawerController,
      builder: (context, child) {
        return DrawerPanel(
          width: _drawerWidth.value,
          isVisible: isVisible,
          fadeAnimation: _fadeAnimation,
          selectedPanel: selectedPanel,
          topology: topology,
          onRetry: onRetry,
        );
      },
    );
  }

  Widget _buildContent(AsyncValue<Topology> topology, OnRetryCallback onRetry) {

    // Logger().d("2 BuildContent called with topology=$topology");
    return Expanded(
            child: Row(
              children: [
                _buildSideNav(),
                _buildDrawerPanel(topology, onRetry),
                const Expanded(child: ContentArea()),
              ],
            )
          );
  }

  void _onRetry(WidgetRef ref) {
    var _ = ref.refresh(topologyProvider.future);
  }

  @override
  void dispose() {
    _drawerController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Logger().d("Triggered drawer rebuild");

    return Consumer(builder: 
      (context, ref, child) {
        var topology = ref.watch(topologyProvider);

        // Logger().d("1 Triggered a drawer rebuild with topology=$topology");
        Future<void> onRetry() async => _onRetry(ref);
        return _buildContent(topology, onRetry);
      }
    );
  }
}
