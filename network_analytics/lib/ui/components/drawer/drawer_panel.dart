import 'package:flutter/material.dart';
import 'package:network_analytics/ui/components/drawer/device_listing_panel.dart';
import 'package:network_analytics/ui/components/drawer/side_nav_item.dart';

class DrawerPanel extends StatelessWidget {
  final double width;
  final bool isVisible;
  final Animation<double> fadeAnimation;
  final SideNavItem? selectedPanel;

  const DrawerPanel({
    super.key,
    required this.width,
    required this.isVisible,
    required this.fadeAnimation,
    required this.selectedPanel,
  });

  Widget createListingPanel() {
    return CollapsibleSection.createExample();
  }

  Widget createContainerFromSelection() {
    switch (selectedPanel) {
      case SideNavItem.listado:
        return createListingPanel();

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
                child: createContainerFromSelection()
              ),
            )
          : const SizedBox.shrink(),
    );
  }


}
