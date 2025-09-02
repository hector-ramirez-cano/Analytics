import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/ui/components/enums/side_nav_item.dart';

class SideNavSelection {
  final SideNavItem selected;

  const SideNavSelection({
    required this.selected,
  });
}

class SideNavSelectionNotifier extends StateNotifier<SideNavSelection> {
  SideNavSelectionNotifier() : super(SideNavSelection(selected: SideNavItem.canvas));

  void setSelected(SideNavItem selection) => state = SideNavSelection(selected: selection);
}
