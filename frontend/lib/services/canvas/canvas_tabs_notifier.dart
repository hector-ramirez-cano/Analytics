import 'package:flutter/material.dart';
import 'package:logger/web.dart';
import 'package:aegis/extensions/development_filter.dart';
import 'package:aegis/models/topology.dart';
import 'package:aegis/models/topology_view/topology_view.dart';
import 'package:aegis/models/topology_view/topology_view_template.dart';
import 'package:aegis/services/topology/topology_provider.dart';
import 'package:aegis/services/topology/topology_view_template_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'canvas_tabs_notifier.g.dart';

class CanvasTabs {
  const CanvasTabs({
    required this.selected,
    required this.order,
    required this.tabs,
    required this.canvasStates
  });

  factory CanvasTabs.empty() => CanvasTabs(selected: null, order: [], tabs: {}, canvasStates: {});

  static Logger logger = Logger(filter: ConfigFilter.fromConfig("debug/enable_canvas_tab_logging", false));

  final Map<UniqueKey, CanvasState> canvasStates;
  final List<UniqueKey> order;
  final UniqueKey? selected;
  final Map<UniqueKey, TopologyView> tabs;

  bool get hasSelectedTab => selected != null && selectedTab != null;

  TopologyView? get selectedTab => tabs[selected];

  CanvasState? get selectedState => canvasStates[selected];

  Offset getPositionInState(int itemId) {
    if (selectedState == null) return Offset.zero;
    if (selectedTab == null) return Offset.zero;

    final member = selectedTab!.template.members[itemId];

    return member?.position ?? Offset.zero;
  }

  CanvasTabs copyWith({
    UniqueKey? selected,
    Map<UniqueKey, TopologyView>? tabs,
    Map<UniqueKey, CanvasState>? canvasStates,
    List<UniqueKey>? order,
  }) {
    return CanvasTabs(
      selected: selected ?? this.selected,
      order: order ?? this.order,
      tabs: tabs ?? this.tabs,
      canvasStates: canvasStates ?? this.canvasStates,
    );
  }
}

// Immutable state class
class CanvasState {
  CanvasState({
    required this.scale,
    required this.centerOffset,
    this.isModified = false,
  });

  factory CanvasState.empty() => CanvasState(scale: 1.0, centerOffset: Offset.zero);

  final Offset centerOffset;
  final bool isModified;
  final double scale;

  CanvasState copyWith({
    double? scale,
    Offset? centerOffset,
    bool? isModified,
    CanvasTabs? canvasTab,
  }) {
    return CanvasState(
      scale: scale ?? this.scale,
      centerOffset: centerOffset ?? this.centerOffset,
      isModified: isModified ?? this.isModified,
    );
  }
}

// Riverpod 3 Notifier
@riverpod
class CanvasTabsNotifier extends _$CanvasTabsNotifier {
  List<(UniqueKey, String)> getTabsByOrder() {
    List<(UniqueKey, String)> values = [];

    for (var positionKey in state.order) {
      var label = state.tabs.containsKey(positionKey) ? state.tabs[positionKey]!.template.name : "";

      values.add((positionKey, label));
    }

    return values;
  }

  Topology? _currentTopology;
  CanvasTabs? _oldState;

  CanvasState? get canvasState => state.canvasStates[state.selected];
  bool get hasTopology => _currentTopology != null;

  void setSelectedTab(UniqueKey id) {
    state = state.copyWith(selected: id);
    _oldState = state;
    CanvasTabs.logger.d("Canvas Tab, Set $id selected");
  }

  void appendTab(TopologyViewTemplate template) {
    var tabs = state.tabs;
    var order = state.order;
    var id = UniqueKey();

    tabs[id] = TopologyView(template: template, topology: _currentTopology!);
    order.add(id);

    CanvasTabs.logger.d("Canvas Tab, Added new tab, title=${template.name}, id=$id");

    // Force rebuild
    state = state.copyWith(tabs: tabs, order: order);
    _oldState = state;
  }

  void removeTab(UniqueKey id) {
    var tabs = state.tabs;
    var selected = state.selected;
    var order = state.order;

    tabs.remove(id);
    order.removeWhere((item) => item == id);

    // if the removed item is the same as the selected, reset selection
    if (id == state.selected) {
      selected = null;
    }

    CanvasTabs.logger.d("Canvas Tab, removed tab, id=$id");

    // Force rebuild
    state = state.copyWith(tabs: tabs, order: order, selected: selected);
    _oldState = state;
  }

  void appendTabs(List<TopologyViewTemplate> items) {
    var tabs = state.tabs;
    var order = state.order;

    for (var item in items) {
      var id = UniqueKey();
      tabs[id] = TopologyView(template: item, topology: _currentTopology!);
      order.add(id);
    }
    
    // Force rebuild
    state = state.copyWith(tabs: tabs, order: order);
    _oldState = state;
  }

  void reoderTabs(int oldIndex, int newIndex) {
    // if (newIndex > oldIndex) newIndex -= 1;
    
    var order = state.order;

    final item = order.removeAt(oldIndex);
    order.insert(newIndex, item);

    // Force rebuild
    state = state.copyWith(order: order);
    _oldState = state;
  }

  void setCanvasPosition(double? scale, Offset? centerOffset) {
    var actualState = canvasState;
    if (actualState == null) return;
    if (state.selected == null) return;

    final changed = (scale != null && scale != actualState.scale) ||
        (centerOffset != null && centerOffset != actualState.centerOffset);

    if (changed) {
      final newCanvasState = actualState.copyWith(
        scale: scale ?? actualState.scale,
        centerOffset: centerOffset ?? actualState.centerOffset,
        isModified: true,
      );

      setCanvasState(newCanvasState);
    }
  }

  /// Sets the canvas state for the current selected canvas tab
  void setCanvasState(CanvasState newCanvasState) {
    final Map<UniqueKey, CanvasState> unitedStates = Map.from(state.canvasStates);
      unitedStates[state.selected!] = newCanvasState;

      state = state.copyWith(canvasStates: unitedStates);
      _oldState = state;
  }

  void resetCanvasState() {    
    final currState = canvasState;
    final canvasStates = state.canvasStates;
    if (currState == null) return;
    if (state.selected == null) return;

    final newCanvasState = currState.copyWith(scale: 1.0, centerOffset: Offset.zero, isModified: false);
    final Map<UniqueKey, CanvasState> newCanvasStates = Map.from(canvasStates);
    newCanvasStates[state.selected!] = newCanvasState;

    state = state.copyWith(canvasStates: newCanvasStates);
    _oldState = state;
  }

  void panCanvas(Offset delta) {
    final oldCanvasState = canvasState;

    if (canvasState == null) return;

    final newCanvasState = oldCanvasState!.copyWith(
      centerOffset: oldCanvasState.centerOffset + delta,
      isModified: true,
    );

    setCanvasState(newCanvasState);
  }

  @override
  CanvasTabs build() {
    final topology = ref.watch(topologyServiceProvider);
    return topology.when(
      error: (_, _) => CanvasTabs.empty(),
      loading: () => CanvasTabs.empty(),
      data: (topology) {

        // Inform every entry of the new topology
        final newTabs = _oldState?.tabs.map((id, prev) => MapEntry(id, prev.copyWith(topology: topology))) ?? {};
        final Map<UniqueKey, CanvasState> newStates = _oldState?.canvasStates ?? {};

        // Temporal, instantiation of the templates for testing
        // TODO: Source this from a dialog selection to add a new view
        final order = _oldState?.order ?? [];
        final templates = ref.watch(topologyViewTemplatesProvider);
        templates.whenData((templates) {
          if (newTabs.isNotEmpty) return;

          final logicView = UniqueKey();
          newTabs[logicView] = TopologyView(topology: topology, template: templates[0]!);
          newStates[logicView] = CanvasState.empty();

          final logicView2 = UniqueKey();
          newTabs[logicView2] = TopologyView(topology: topology, template: templates[1]!);
          newStates[logicView2] = CanvasState.empty();

          final geoView = UniqueKey();
          newTabs[geoView] = TopologyView(topology: topology, template: templates[2]!);
          newStates[geoView] = CanvasState.empty();

          order.add(logicView);
          order.add(logicView2);
          order.add(geoView);
        });

        // Recreate the canvasTab and save the topology for reference while the provider is alive
        _currentTopology = topology;

        return CanvasTabs(selected: _oldState?.selected, order: order, tabs: newTabs, canvasStates: newStates);
      },
    );
  }
}
