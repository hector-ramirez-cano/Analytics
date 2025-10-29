import 'dart:convert';

import 'package:free_map/free_map.dart';
import 'package:http/http.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/models/alerts/alert_predicate.dart';
import 'package:network_analytics/models/alerts/alert_rule.dart';
import 'package:network_analytics/models/analytics_item.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/link.dart';
import 'package:network_analytics/models/link_type.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/services/alerts/alert_rules_service.dart';
import 'package:network_analytics/services/app_config.dart';
import 'package:network_analytics/services/topology/topology_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'item_edit_selection_notifier.g.dart';

class ItemEditDelta {
  final Topology topologyChanges;
  final Topology topologyDeletions;
  final AlertRuleSet ruleSetChanges;
  final AlertRuleSet ruleSetDeletions;

  ItemEditDelta({
    required this.topologyChanges,
    required this.topologyDeletions,
    required this.ruleSetChanges,
    required this.ruleSetDeletions,
  });

  factory ItemEditDelta.empty() {
    return ItemEditDelta(
      topologyChanges: Topology.empty(),
      topologyDeletions: Topology.empty(),
      ruleSetChanges: AlertRuleSet.empty(),
      ruleSetDeletions: AlertRuleSet.empty()
    );
  }

  ItemEditDelta copyWith({
    Topology? topologyChanges,
    Topology? topologyDeletions,
    AlertRuleSet? ruleSetChanges,
    AlertRuleSet? ruleSetDeletions,
  }) {
    return ItemEditDelta(
      topologyChanges: topologyChanges ?? this.topologyChanges ,
      topologyDeletions: topologyDeletions ?? this.topologyDeletions ,
      ruleSetChanges: ruleSetChanges ?? this.ruleSetChanges ,
      ruleSetDeletions: ruleSetDeletions ?? this.ruleSetDeletions ,
    );
  }

  bool hasChanges() {
    return topologyChanges.items.isNotEmpty 
    || topologyDeletions.items.isNotEmpty
    || ruleSetChanges.rules.isNotEmpty
    || ruleSetDeletions.rules.isNotEmpty;
  }

  bool isDeleted(dynamic item) {
    return 
      topologyDeletions.items.containsKey(item.id)
      || ruleSetDeletions.rules.containsKey(item.id);
  }
}

class ItemEditSelection {
  final List<AnalyticsItem> selectedStack;
  final ItemEditDelta itemEditDelta;
  final bool editingGroupName;
  final bool editingGroupMembers;
  final bool editingLinkIfaceA;
  final bool editingLinkIfaceB;
  final bool editingLinkDeviceA;
  final bool editingLinkDeviceB;
  final bool editingLinkType;
  final bool editingDeviceName;
  final bool editingDeviceHostname;
  final bool editingDeviceMetadata;
  final bool editingDeviceMetrics;
  final bool editingDeviceDataSources;
  final bool editingDeviceGeoPosition;
  final bool editingAlertName;
  final bool editingAlertMembers;
  final bool confirmDeletion;
  final bool creatingItem;


  const ItemEditSelection({
    required this.selectedStack,
    required this.itemEditDelta,
    required this.editingGroupName,
    required this.editingGroupMembers,
    required this.editingDeviceName,
    required this.editingLinkIfaceB,
    required this.editingLinkIfaceA,
    required this.editingLinkDeviceA,
    required this.editingLinkDeviceB,
    required this.editingLinkType,
    required this.editingDeviceHostname,
    required this.editingDeviceMetadata,
    required this.editingDeviceMetrics,
    required this.editingDeviceDataSources,
    required this.editingDeviceGeoPosition,
    required this.editingAlertName,
    required this.editingAlertMembers,
    required this.confirmDeletion,
    required this.creatingItem,
  });
}

@riverpod
class ItemEditSelectionNotifier extends _$ItemEditSelectionNotifier{
  @override ItemEditSelection build() => ItemEditSelection(
      selectedStack: [],
      itemEditDelta: ItemEditDelta.empty(),
      confirmDeletion: false,
      editingGroupName: false,
      editingGroupMembers: false,
      editingDeviceName: false,
      editingDeviceHostname: false,
      editingLinkIfaceA: false,
      editingLinkIfaceB: false,
      editingLinkDeviceA: false,
      editingLinkDeviceB: false,
      editingLinkType: false,
      editingDeviceMetadata: false,
      editingDeviceMetrics: false,
      editingDeviceDataSources: false,
      editingDeviceGeoPosition: false,
      editingAlertName: false,
      editingAlertMembers: false,
      creatingItem: false,
      );

  void setSelected(AnalyticsItem item, {bool appendState = false, bool clearStack = false, bool appendToTopology = false}) {
    var newStack = state.selectedStack;
    Map<int, dynamic> items = Map.from(state.itemEditDelta.topologyChanges.items);

    if (clearStack) {
      newStack = [];
    }

    if (appendState || newStack.isEmpty) {
      newStack.add(item);
    }

    if (appendToTopology) {
      items[item.id] = item;
    }

    set(selected: newStack, changes: state.itemEditDelta.topologyChanges.copyWith(items: items));
  }

  bool toggleEditingGroupName() {
    bool editing = !state.editingGroupName;
    set(editingGroupName: editing);

    return editing;
  }

    bool toggleEditingAlertName() {
    bool editing = !state.editingAlertName;
    set(editingAlertName: editing);

    return editing;
  }

  void set({
    List<AnalyticsItem>? selected,
    Topology? changes,
    Topology? deleted,
    AlertRuleSet ? ruleChanges,
    AlertRuleSet ? ruleDeletions,
    bool requestedConfirmDeletion = false,
    bool editingGroupMembers = false,
    bool editingGroupName = false,
    bool editingDeviceName = false,
    bool editingHostname = false,
    bool editingLinkIfaceA = false,
    bool editingLinkIfaceB = false,
    bool editingLinkDeviceA = false,
    bool editingLinkDeviceB = false,
    bool editingLinkType = false,
    bool editingDeviceMetadata = false,
    bool editingDeviceMetrics = false,
    bool editingDeviceGeoPosition = false,
    bool editingDeviceDataSources = false,
    bool editingAlertName = false,
    bool editingAlertMembers = false,

    bool keepState = false,
    bool? overrideCreatingItem,
  }) {
    ItemEditDelta delta;
    if (changes != null || deleted != null || ruleChanges != null || ruleDeletions != null) {
      // only create a new instance if it makes sense to create a new instance
      delta = state.itemEditDelta.copyWith(
        topologyChanges: changes,
        topologyDeletions: deleted,
        ruleSetChanges: ruleChanges,
        ruleSetDeletions: ruleDeletions,
      );
    } else {
      delta = state.itemEditDelta;
    }

    if (keepState) {
      state = ItemEditSelection(
        selectedStack         : selected ?? state.selectedStack,
        confirmDeletion       : state.confirmDeletion,
        editingGroupName      : state.editingGroupName,
        editingGroupMembers   : state.editingGroupMembers,
        editingDeviceName     : state.editingDeviceName,
        editingDeviceHostname : state.editingDeviceHostname,
        editingLinkIfaceA     : state.editingLinkIfaceA,
        editingLinkIfaceB     : state.editingLinkIfaceB,
        editingDeviceMetadata : state.editingDeviceMetadata,
        editingDeviceMetrics  : state.editingDeviceMetrics,
        editingLinkDeviceA    : state.editingLinkDeviceA,
        editingLinkDeviceB    : state.editingLinkDeviceB,
        editingLinkType       : state.editingLinkType,
        creatingItem          : state.creatingItem,
        editingAlertName      : state.editingAlertName,
        editingAlertMembers   : state.editingAlertMembers,
        editingDeviceDataSources: state.editingDeviceDataSources,
        editingDeviceGeoPosition: state.editingDeviceGeoPosition,
        itemEditDelta: delta
      );
    } else {
      state = ItemEditSelection(
        selectedStack              : selected ?? state.selectedStack,
        confirmDeletion       : requestedConfirmDeletion,
        editingGroupName      : editingGroupName,
        editingGroupMembers   : editingGroupMembers,
        editingDeviceName     : editingDeviceName,
        editingDeviceHostname : editingHostname,
        editingLinkIfaceA     : editingLinkIfaceA,
        editingLinkIfaceB     : editingLinkIfaceB,
        editingDeviceMetadata : editingDeviceMetadata,
        editingDeviceMetrics  : editingDeviceMetrics,
        editingLinkDeviceA    : editingLinkDeviceA,
        editingLinkDeviceB    : editingLinkDeviceB,
        editingLinkType       : editingLinkType,
        creatingItem          : overrideCreatingItem ?? state.creatingItem,
        editingAlertName      : editingAlertName,
        editingAlertMembers   : editingAlertMembers,
        editingDeviceDataSources: editingDeviceDataSources,
        editingDeviceGeoPosition: editingDeviceGeoPosition,
        itemEditDelta: delta
      );
    }
  }

  void changeItem(dynamic item) {
    if (item is AlertRule) {
      final ruleSet = state.itemEditDelta.ruleSetChanges.copyWith(rules: {...state.itemEditDelta.ruleSetChanges.rules, item.id : item});
      set(ruleChanges: ruleSet, keepState: true);
    } else {
      final topology = state.itemEditDelta.topologyChanges.copyWith(items: {...state.itemEditDelta.topologyChanges.items, item.id : item});
      set(changes: topology, keepState: true);
    }

  }

  void discard() {
    set(
      changes: Topology.empty(),
      deleted: Topology.empty(),
      ruleChanges: AlertRuleSet.empty(),
      ruleDeletions: AlertRuleSet.empty() ,
      selected: [],
      overrideCreatingItem: false
    );
  }

  void apply() async {
    final changeMessage = {
      "topology-changes"  : state.itemEditDelta.topologyChanges.toMap(),
      "topology-deletions": state.itemEditDelta.topologyDeletions.toMap(),
      "ruleset-changes"   : state.itemEditDelta.ruleSetChanges.toMap(),
      "ruleset-deletions" : state.itemEditDelta.ruleSetDeletions.toMap(),
    };

    final url = Uri.parse(AppConfig.getOrDefault("api/configure_endpoint"));
    final headers = {'Content-Type': 'application/json'};

    // TODO: Handle failed request, retry and if failed, show it to the UI
    try {
      final response = await post(url, headers: headers, body: jsonEncode(changeMessage));

      if (response.statusCode != 200) {
        throw Exception("[BACKEND] Status Code = ${response.statusCode} with error='${response.body}'");
      }

      // discard whatever was stored here, it's already commited
      discard();

      // force update topology and ruleset
      ref.invalidate(topologyServiceProvider);
      ref.invalidate(alertRulesServiceProvider);

    } catch (exception, _) {
      Logger().e("Failed to post changes to backend with error = '${exception.toString()}'");
    }
  }

  void onEditDeviceHostname()    => set(editingHostname: true);
  void onEditDeviceName()        => set(editingDeviceName: true);
  void onEditDeviceGeoposition() => set(editingDeviceGeoPosition: true);
  void onEditMetadata()          => set(editingDeviceMetadata: true);
  void onEditMetrics()           => set(editingDeviceMetrics: true);
  void onEditDataSources()       => set(editingDeviceDataSources: true);
  void onEditAlertName()         => set(editingAlertName: true);
  void onRequestDeletion()       => set(requestedConfirmDeletion: true);

  void onChangeDeviceMgmtHostname(String text) {
    if (selected is! Device || (selected as Device).name == text) { return; }

    changeItem(device.copyWith(mgmtHostname: text));
  }

  void onChangeDeviceNameContent(String text) {
    if (selected is! Device || (selected as Device).name == text) { return; }

    changeItem(device.copyWith(name: text));
  }

  void onChangeSelectedMetric(String option, bool? state) {
    if (selected is! Device) { Logger().w("Changed metric on a device, where device isn't selected"); return; }

    var metrics = Set.from((selected as Device).requestedMetrics);
    if (state == false)     { metrics.remove(option); }
    else if (state == true) { metrics.add(option);    }
    else { Logger().d("Warning, selected metric with tri-state. Tri-states on metrics aren't supported"); return; }

    changeItem((selected as Device).copyWith(requestedMetrics: metrics));
  }

  void onChangeSelectedMetadata(String option, bool? state) {
    if (selected is! Device) { Logger().w("Changed metadata on a device, where device isn't selected"); return; }

    var metadata = Set.from((selected as Device).requestedMetadata);
    if (state == false)     { metadata.remove(option); }
    else if (state == true) { metadata.add(option);    }
    else { Logger().d("Warning, selected metadata with tri-state. Tri-states on metadata aren't supported"); return; }

    changeItem((selected as Device).copyWith(requestedMetadata: metadata));
  }

  void onChangeSelectedDatasource(String option, bool? state) {
    if (selected is! Device) { Logger().w("Changed datasource on a device, where device isn't selected"); return; }

    var datasource = Set.from((selected as Device).dataSources);
    if (state == false)     { datasource.remove(option); }
    else if (state == true) { datasource.add(option);    }
    else { Logger().d("Warning, selected datasource with tri-state. Tri-states on datasource aren't supported"); return; }

    changeItem(device.copyWith(dataSources: datasource));
  }

  void onChangeDeviceGeoPosition(LatLng newPosition) {
    if (selected is! Device) { Logger().w("Changed geoposition on a device, where device isn't selected"); return; }

    changeItem(device.copyWith(geoPosition: newPosition));
  }

  void onChangeLinkDeviceA(Device newDevice) {
    if (selected is! Link) { Logger().w("Changed device in link, where link isn't selected"); return; }

    changeItem(link.copyWith(sideA: newDevice));
  }

  void onChangeLinkDeviceB(Device newDevice) {
    if (selected is! Link) { Logger().w("Changed device in link, where link isn't selected"); return; }

    changeItem(link.copyWith(sideB: newDevice));
  }

  void onChangeLinkType(LinkType type) {
    if (selected is! Link) { Logger().w("Changed link type in link, where link isn't selected"); return; }

    changeItem(link.copyWith(linkType: type));
  }

  void onDeleteSelected() {
    Map<int, dynamic> items = Map.from(state.itemEditDelta.topologyDeletions.items);
    items[selected.id] = selected;

    var selectedStack = state.selectedStack..removeLast();

    // add selected to deleted only if we're not in the middle of creating an item
    if (!state.creatingItem) {
      set(deleted: state.itemEditDelta.topologyDeletions.copyWith(items: items), selected: selectedStack);
    } else {
      set(selected: selectedStack, overrideCreatingItem: false);
    }
  }

  void onRestoreSelected() {
    Map<int, dynamic> items = Map.from(state.itemEditDelta.topologyDeletions.items);
    items.remove(selected.id);

    set(deleted: state.itemEditDelta.topologyDeletions.copyWith(items: items));
  }

  void onToggleRequiresAckInput(bool requiresAck) {
    if (selected is! AlertRule) { Logger().w("Changed requires Ack in alertRule, where alertRule isn't selected"); return; }

    final rules = alertRule.copyWith(requiresAck: requiresAck);

    changeItem(rules);
  }

  void onAddPredicate(AlertPredicate predicate) {
    if (selected is! AlertRule) { Logger().w("Changed requires Ack in alertRule, where alertRule isn't selected"); return; }
  
    final rules = alertRule.copyWith(definition: [...alertRule.definition, predicate]);

    changeItem(rules);
  }

  void onUpdatePredicate(AlertPredicate oldPredicate, AlertPredicate predicate) {
    if (selected is! AlertRule) { Logger().w("Changed requires Ack in alertRule, where alertRule isn't selected"); return; }
  
    final newDefinition = alertRule.definition.map((p) => p == oldPredicate ? predicate : p).toList();

    final rules = alertRule.copyWith(definition: newDefinition);

    changeItem(rules);
  }

  void onRemovePredicate(AlertPredicate predicate) {
    if (selected is! AlertRule) { Logger().w("Changed requires Ack in alertRule, where alertRule isn't selected"); return; }
  
    final rules = alertRule.copyWith(definition: alertRule.definition.where((curr) => curr != predicate).toList());

    changeItem(rules);
  }

  bool isDeleted(dynamic item) {
    return state.itemEditDelta.isDeleted(item);
  }

  bool get hasChanges {
    return state.itemEditDelta.hasChanges();
  }

  AnalyticsItem get selected {
    dynamic changed;
    if (state.selectedStack.last is AlertRule) {
      changed = state.itemEditDelta.ruleSetChanges.rules[state.selectedStack.last.id];
    } else {
      changed = state.itemEditDelta.topologyChanges.items[state.selectedStack.last.id];
    }

    // no changes have been made, return as is
    if (changed == null) {
      return state.selectedStack.last;
    }

    // has been modified, return as is
    return changed;
  }

  dynamic get selectedMerged {
    dynamic changed;
    if (state.selectedStack.last is AlertRule) {
      changed = state.itemEditDelta.ruleSetChanges.rules[state.selectedStack.last.id];
    } else {
      changed = state.itemEditDelta.topologyChanges.items[state.selectedStack.last.id];
    }

    // no changes have been made, return as is
    if (changed == null) {
      return state.selectedStack;
    }

    // has been modified, return as original+changed
    return changed.mergeWith(state.selectedStack);
  }

  Device get device {
    AnalyticsItem curr = selected;

    if (curr is! Device) {
      Logger().e("Accessed item for edit, where item isn't a Device. SelectedItem = $curr");
    }

    return curr as Device;
  }

  Device get deviceMerged {
    return device.mergeWith(state.selectedStack.last as Device);
  }

  Group get group {
    dynamic curr = selected;

    if (curr is! Group) {
      Logger().e("Accessed item for edit, where item isn't a Group. SelectedItem = $curr");
    }

    return curr as Group;
  }

  Link get link {
    dynamic curr = selected;

    if (curr is! Link) {
      Logger().e("Accessed item for edit, where item isn't a Link. SelectedItem = $curr");
    }

    return curr as Link;
  }

  AlertRule get alertRule {
    dynamic curr = selected;

    if (curr is! AlertRule) {
      Logger().e("Accessed item for edit, where item isn't an AlertRule. SelectedItem = $curr");
    }

    return curr as AlertRule;
  }
}
