import 'package:aegis/models/enums/navigation_rail_item.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'screen_selection_notifier.g.dart';

@riverpod
class SideNavSelection extends _$SideNavSelection {

  @override NavigationRailItem? build() =>  NavigationRailItem.charts;

  void setSelected(NavigationRailItem? selection) => state = selection;
}
