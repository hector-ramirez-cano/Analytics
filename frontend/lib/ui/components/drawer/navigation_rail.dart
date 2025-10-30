import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aegis/services/drawer_state_notifier.dart';
import 'package:aegis/services/screen_selection_notifier.dart';
import 'package:aegis/models/enums/navigation_rail_item.dart';

class AnalyticsNavigationRail extends StatelessWidget {
  const AnalyticsNavigationRail({super.key});

  void _setScreen(NavigationRailItem? selected, WidgetRef ref) {

    if (selected == null) { return; }

    ref.read(sideNavSelectionProvider.notifier).setSelected(selected);
    ref.read(drawerStateProvider.notifier).setState(selected.hasDrawer);
  }

  // List<Widget> _bottomItems (WidgetRef ref) {
  //   return NavigationRailItem.bottomItems.map((item) {
  //     return IconButton(
  //         icon: Icon(item.icon),
  //         onPressed: () => _setScreen(item, ref),
  //     );
  //   }).toList();
  // }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      child: Consumer(builder: (context, ref, _) => _makeNavigationRail(ref)) ,
    );
  }

  NavigationRail _makeNavigationRail(WidgetRef ref) {
    return NavigationRail(
      selectedIndex: ref.watch(sideNavSelectionProvider)?.index,
      onDestinationSelected: (dest) => _setScreen(NavigationRailItem.values[dest], ref),

      // spacing
      leading: Padding(padding: EdgeInsetsGeometry.only(top: 16)),

      // Top destinations, handled automatically
      destinations: [],

      // Bottom destinations, handled manually
      // trailing: Expanded(
      //   child: Column(
      //     mainAxisSize: MainAxisSize.max,
      //     mainAxisAlignment: MainAxisAlignment.end,
      //     children: [
      //       Divider(indent: 10, endIndent: 10,),
      //       ..._bottomItems(ref),
      //       Padding(padding: EdgeInsetsGeometry.only(bottom: 12))
      //     ]
      //   ),
      // )
    );
  }
  
}