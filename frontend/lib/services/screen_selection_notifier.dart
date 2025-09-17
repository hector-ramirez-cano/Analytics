import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/ui/components/enums/navigation_rail_item.dart';

class SideNavSelection {
  final NavigationRailItem? selected;

  const SideNavSelection({
    required this.selected,
  });
}

class SideNavSelectionNotifier extends StateNotifier<SideNavSelection> {
  SideNavSelectionNotifier() : super(SideNavSelection(selected: NavigationRailItem.canvas));

  void setSelected(NavigationRailItem? selection) => state = SideNavSelection(selected: selection);
}
