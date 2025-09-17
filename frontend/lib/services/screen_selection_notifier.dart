import 'package:network_analytics/ui/components/enums/navigation_rail_item.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'screen_selection_notifier.g.dart';

class _SideNavSelection {
  final NavigationRailItem? selected;

  const _SideNavSelection({
    required this.selected,
  });
}

@riverpod
class SideNavSelection extends _$SideNavSelection {

  @override _SideNavSelection build() =>  _SideNavSelection(selected: NavigationRailItem.canvas);

  void setSelected(NavigationRailItem? selection) => state = _SideNavSelection(selected: selection);
}
