import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/extensions/development_filter.dart';

import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/services/screen_selection_notifier.dart';
import 'package:network_analytics/ui/components/enums/side_nav_item.dart';
import 'package:network_analytics/ui/components/enums/workplace_screen.dart';
import 'package:network_analytics/ui/components/retry_indicator.dart';
import 'package:network_analytics/ui/components/side_nav.dart';
import 'package:network_analytics/ui/components/drawer/drawer_panel.dart';

// TODO: Convert into stateless via Riverpod
class SideDrawer extends StatefulWidget {
  const SideDrawer({super.key});

  @override
  State<SideDrawer> createState() => _DrawerState();
}

class _DrawerState extends State<SideDrawer> with TickerProviderStateMixin {
  static Logger logger = Logger(filter: ConfigFilter.fromConfig("debug/enable_drawer_logging", false));

  SideNavItem? selectedPanel = SideNavItem.canvas;
  Topology? topology;
  bool isDrawerOpened = true;
  WorkplaceScreen screen = WorkplaceScreen.canvas;

  final double drawerTargetWidth = 250;
  late final AnimationController _drawerController;
  late final Animation<double> _drawerWidth;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  late SideNavSelectionNotifier _screenSelectionNotifier;

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

    _drawerController.forward();
  }

  void _handleNavClick(SideNavItem clickedItem) {
    SideNavItem? selected;
    bool setOpen;
    if (selectedPanel == clickedItem) {
      if (isDrawerOpened) {
        // clicked the same, we gotta close
        selected = null;
        setOpen = false;
      } else {
        // clicked the same, but it was forcefully hidden, keep the same, but open the drawer
        selected = selectedPanel;
        setOpen = true;
      }
    } else {
      // clicked something else, switch to that
      selected = clickedItem;
      setOpen = true;
    }

    // if the drawer doesn't have a drawer, force it to close
    setOpen &= clickedItem.hasDrawer;

    setState(() {
      selectedPanel = selected;
    });

    _setDrawerState(setOpen);
    _setScreen(selected, _screenSelectionNotifier);
  }

  void _setDrawerState(bool open) {
    if (open) {
      _drawerController.forward();
    } else {
      _drawerController.reverse();
    }

    isDrawerOpened = open;
  }

  void _setScreen(SideNavItem? selected, SideNavSelectionNotifier screenSelectionNotifier) {

    if (selected == null) { return; }

    screenSelectionNotifier.setSelected(selected);
  }

  SideNav _buildSideNav() {
    return SideNav(
      selectedPanel: selectedPanel,
      onPressed: _handleNavClick,
    );
  }

  AnimatedBuilder _buildDrawerPanel(AsyncValue<Topology> topology, OnRetryCallback onRetry) {
    logger.d("3 _buildDrawerPanel called, selectedPanel=$selectedPanel, status=${_drawerController.status}");
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

    logger.d("2 BuildContent called with topology=$topology");
    return 
      Row(
        children: [
          _buildSideNav(),
          _buildDrawerPanel(topology, onRetry),
        ],
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
    logger.d("Triggered drawer rebuild");

    return Consumer(builder: 
      (context, ref, child) {
        var topology = ref.watch(topologyProvider);
        _screenSelectionNotifier = ref.read(screenSelectionNotifier.notifier);

        logger.d("1 Triggered a drawer rebuild with topology=$topology");
        Future<void> onRetry() async => _onRetry(ref);
        return _buildContent(topology, onRetry);
      }
    );
  }
}
