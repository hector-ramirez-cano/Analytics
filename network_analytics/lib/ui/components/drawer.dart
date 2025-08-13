import 'package:flutter/material.dart';
import 'package:network_analytics/models/topology.dart';
import 'side_nav.dart';
import 'drawer_panel.dart';
import 'content_area.dart';

class SideDrawer extends StatefulWidget {
  const SideDrawer({super.key});

  @override
  State<SideDrawer> createState() => _DrawerState();
}

class _DrawerState extends State<SideDrawer> with TickerProviderStateMixin {
  int? selectedIndex;
  Topology? topology;

  final double drawerTargetWidth = 250;
  late final AnimationController _drawerController;
  late final Animation<double> _drawerWidth;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  final List<IconData> navIcons = [Icons.segment, Icons.search, Icons.settings];
  final List<String> navLabels = ['Listado', 'Search', 'Settings'];

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

  void _handleNavClick(int index) {
    if (selectedIndex == index) {
      _drawerController.reverse();
      setState(() {
        selectedIndex = null;
      });
    } else {
      setState(() {
        selectedIndex = index;
      });
      _drawerController.forward();
    }
  }


  @override
  void dispose() {
    _drawerController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          SideNav(
            selectedIndex: selectedIndex,
            icons: navIcons,
            labels: navLabels,
            onPressed: _handleNavClick,
          ),
          AnimatedBuilder(
            animation: _drawerController,
            builder: (context, child) {
              return DrawerPanel(
                width: _drawerWidth.value,
                isVisible: selectedIndex != null &&
                    _drawerController.status == AnimationStatus.completed,
                fadeAnimation: _fadeAnimation,
                label: navLabels[selectedIndex ?? 0],
              );
            },
          ),
          const Expanded(child: ContentArea()),
        ],
      )
    );
  }
}
