import 'package:flutter/cupertino.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/extensions/development_filter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'canvas_tab_notifier.g.dart';

class _CanvasTab {
  static Logger logger = Logger(filter: ConfigFilter.fromConfig("debug/enable_canvas_tab_logging", false));


  final UniqueKey? selected;
  final Map<UniqueKey, String> tabs;
  final List<UniqueKey> order;


  const _CanvasTab({
    required this.selected,
    required this.order,
    required this.tabs
  });
}

@riverpod
class CanvasTab extends _$CanvasTab {
  
  @override _CanvasTab build() => _CanvasTab(selected: null, order: [], tabs: {});


  void setSelected(UniqueKey id) {
    state = _CanvasTab(
        selected: id, 
        tabs: state.tabs,
        order: state.order,
    );
    _CanvasTab.logger.d("Canvas Tab, Set $id selected");
  }

  void append(String title) {
    var tabs = state.tabs;
    var selected = state.selected;
    var order = state.order;
    var id = UniqueKey();

    tabs[id] = title;
    order.add(id);

    _CanvasTab.logger.d("Canvas Tab, Added new tab, title=$title, id=$id");

    // Force rebuild
    state = _CanvasTab(selected: selected, tabs: tabs, order: order);
  }

  void remove(UniqueKey id) {
    var tabs = state.tabs;
    var order = state.order;
    var selected = state.selected;

    tabs.remove(id);
    order.removeWhere((item) => item == id);

    // if the removed item is the same as the selected, reset selection
    if (id == state.selected) {
      selected = null;
    }


    _CanvasTab.logger.d("Canvas Tab, removed tab, id=$id");

    // Force rebuild
    state = _CanvasTab(selected: selected, tabs: tabs, order: order);
  }

  void appends(List<String> items) {
    var tabs     = state.tabs;
    var order    = state.order;
    var selected = state.selected;

    for (var item in items) {
      var id = UniqueKey();
      tabs[id] = item;
      order.add(id);
    }
    
    // Force rebuild
    state = _CanvasTab(selected: selected, tabs: tabs, order: order);
  }

  void reoder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    
    var order = state.order;

    final item = order.removeAt(oldIndex);
    order.insert(newIndex, item);

    // Force rebuild
    state = _CanvasTab(selected: state.selected, order: order, tabs: state.tabs);
  }

  List<(UniqueKey, String)> getTabsByOrder() {
    List<(UniqueKey, String)> values = [];

    for (var positionKey in state.order) {
      var label = state.tabs.containsKey(positionKey) ? state.tabs[positionKey]! : "";

      values.add((positionKey, label));
    }

    return values;
  }
}
