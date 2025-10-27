import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ignore: unused_import
import 'package:logger/web.dart';
import 'package:network_analytics/services/drawer_state_notifier.dart';
import 'package:network_analytics/services/item_edit_selection_notifier.dart';
import 'package:network_analytics/services/screen_selection_notifier.dart';
import 'package:network_analytics/ui/components/drawer/drawer.dart';
import 'package:network_analytics/models/enums/navigation_rail_item.dart';
import 'package:network_analytics/theme/app_colors.dart';

class SideNav extends StatelessWidget {

  const SideNav({
    super.key,
  });

  void _setScreen(NavigationRailItem? selected, WidgetRef ref) {

    if (selected == null) { return; }

    ref.read(sideNavSelectionProvider.notifier).setSelected(selected);
    ref.read(itemEditSelectionProvider.notifier).discard();
  }

  void _handleNavClick(NavigationRailItem clickedItem, WidgetRef ref) {
    NavigationRailItem? selected;
    bool setOpen;
    final selectedPanel = ref.watch(sideNavSelectionProvider);
    final isDrawerOpened = ref.watch(drawerStateProvider).isOpen;
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

    ref.read(drawerStateProvider.notifier).setState(setOpen);

    _setScreen(selected, ref);

    SideDrawer.logger.d("Interacted with Nav, newSelected = $selected, drawerState isDrawerOpened=$setOpen");
  }

    Widget _buildChild(NavigationRailItem? selectedPanel, NavigationRailItem panel, WidgetRef ref) {
    final isSelected = panel == selectedPanel;
    return Padding(
      key: ValueKey(panel),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: IconButton(
        icon: Icon(panel.icon),
        tooltip: panel.label,
        color: isSelected
            ? AppColors.selectedIconColor
            : Colors.white,
        onPressed: () => _handleNavClick(panel, ref),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder:(context, ref, child) {
      final selectedPanel = ref.read(sideNavSelectionProvider);

      List<Widget> topItems = List.generate(NavigationRailItem.topItems.length, (index) => _buildChild(selectedPanel, NavigationRailItem.topItems[index], ref));
      List<Widget> bottomItems = List.generate(NavigationRailItem.bottomItems.length, (index) => _buildChild(selectedPanel, NavigationRailItem.bottomItems[index], ref));

      return Container(
        width: 60,
        color: AppColors.sidebarColor,
        child: LayoutBuilder(builder: (context, constraints) {
          final height = (NavigationRailItem.values.length ) * 64;
          if (height > constraints.maxHeight) {
            return ListView(
              children: [...topItems, ...bottomItems]
            );
          }
          return Column(children: [...topItems, Spacer(), ...bottomItems],);
        })
        
      );
    });
  }

}
