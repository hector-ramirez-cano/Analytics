import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/components/enums/navigation_rail_item.dart';

class AnalyticsNavigationRail extends StatelessWidget {
  const AnalyticsNavigationRail({super.key});

  void _setScreen(NavigationRailItem? selected, WidgetRef ref) {

    if (selected == null) { return; }

    ref.read(screenSelectionNotifier.notifier).setSelected(selected);
    ref.read(drawerStateNotifier.notifier).setState(selected.hasDrawer);
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
      selectedIndex: ref.watch(screenSelectionNotifier).selected?.index,
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