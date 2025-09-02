// ignore_for_file: avoid_init_to_null

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';

class CanvasTab {
  final UniqueKey? selected;
  final Map<UniqueKey, String> tabs;
  final List<UniqueKey> order;


  const CanvasTab({
    required this.selected,
    required this.order,
    required this.tabs
  });
}

class CanvasTabNotifier extends StateNotifier<CanvasTab> {
  CanvasTabNotifier() : super(CanvasTab(selected: null, order: [], tabs: {}));

  void setSelected(UniqueKey id) {
      state = CanvasTab(
        selected: id, 
        tabs: state.tabs,
        order: state.order,
    );

    Logger().d("Set $id selected");
  }

  void append(String title) {
    var tabs = state.tabs;
    var selected = state.selected;
    var order = state.order;
    var id = UniqueKey();

    tabs[id] = title;
    order.add(id);

    // Force rebuild
    state = CanvasTab(selected: selected, tabs: tabs, order: order);
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

    // Force rebuild
    state = CanvasTab(selected: selected, tabs: tabs, order: order);
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
    state = CanvasTab(selected: selected, tabs: tabs, order: order);
  }

  void reoder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    
    var order = state.order;

    final item = order.removeAt(oldIndex);
    order.insert(newIndex, item);

    // Force rebuild
    state = CanvasTab(selected: state.selected, order: order, tabs: state.tabs);
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
