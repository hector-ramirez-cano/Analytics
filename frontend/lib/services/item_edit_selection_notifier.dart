import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_map/free_map.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/link.dart';
import 'package:network_analytics/models/link_type.dart';
import 'package:network_analytics/models/topology.dart';

class ItemEditSelection {
  final List<dynamic> selectedStack;
  final Topology changes;
  final Topology deleted;
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
  final bool confirmDeletion;
  

  const ItemEditSelection({
    required this.selectedStack,
    required this.changes,
    required this.deleted,
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
    required this.confirmDeletion,
  });
}

class ItemEditSelectionNotifier extends StateNotifier<ItemEditSelection> {
  ItemEditSelectionNotifier() 
  : super(
    ItemEditSelection(
      selectedStack: [],
      changes: Topology(items: {}),
      deleted: Topology(items: {}),
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
      )
    );

  void setSelected(dynamic item) {
    var newStack = state.selectedStack..add(item);

    set(selected: newStack);
  }

  bool toggleEditingGroupName() {
    bool editing = !state.editingGroupName;
    set(editingGroupName: editing);

    return editing;
  }

  void set({
    List<dynamic>? selected,
    Topology? changes,
    Topology? deleted,
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

    bool keepState = false,
  }) {
    if (keepState) {
      state = ItemEditSelection(
        selectedStack              : selected ?? state.selectedStack,
        deleted               : deleted ?? state.deleted,
        changes               : changes ?? state.changes,
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
        editingDeviceDataSources: state.editingDeviceDataSources,
        editingDeviceGeoPosition: state.editingDeviceGeoPosition,
      );
    } else {
      state = ItemEditSelection(
        selectedStack              : selected ?? state.selectedStack,
        changes               : changes ?? state.changes,
        deleted               : deleted ?? state.deleted,
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
        editingDeviceDataSources: editingDeviceDataSources,
        editingDeviceGeoPosition: editingDeviceGeoPosition,
      );
    }
  }

  void changeItem(dynamic item) {
    final topology = state.changes.cloneWith(items: {...state.changes.items, item.id : item});

    set(changes: topology, keepState: true);
  }

  void discard() {
    set(changes: Topology(items: {}), deleted: Topology(items: {}), selected: [], );
  }

  void onEditDeviceHostname()    => set(editingHostname: true);
  void onEditDeviceName()        => set(editingDeviceName: true);
  void onEditDeviceGeoposition() => set(editingDeviceGeoPosition: true);
  void onEditMetadata()          => set(editingDeviceMetadata: true);
  void onEditMetrics()           => set(editingDeviceMetrics: true);
  void onEditDataSources()       => set(editingDeviceDataSources: true);
  void onRequestDeletion()       => set(requestedConfirmDeletion: true);

  void onChangeDeviceMgmtHostname(String text) {
    if (selected is! Device || selected.name == text) { return; }

    changeItem(device.cloneWith(mgmtHostname: text));
  }

  void onChangeDeviceNameContent(String text) {
    if (selected is! Device || selected.name == text) { return; }

    changeItem(device.cloneWith(name: text));
  }

  void onChangeSelectedMetric(String option, bool? state) {
    if (selected is! Device) { Logger().w("Changed metric on a device, where device isn't selected"); return; }
    
    var metrics = Set.from((selected as Device).requestedMetrics);
    if (state == false)     { metrics.remove(option); }
    else if (state == true) { metrics.add(option);    }
    else { Logger().d("Warning, selected metric with tri-state. Tri-states on metrics aren't supported"); return; }

    changeItem(selected.cloneWith(requestedMetrics: metrics));
  }

  void onChangeSelectedMetadata(String option, bool? state) {
    if (selected is! Device) { Logger().w("Changed metadata on a device, where device isn't selected"); return; }
    
    var metadata = Set.from((selected as Device).requestedMetadata);
    if (state == false)     { metadata.remove(option); }
    else if (state == true) { metadata.add(option);    }
    else { Logger().d("Warning, selected metadata with tri-state. Tri-states on metadata aren't supported"); return; }

    changeItem(selected.cloneWith(requestedMetadata: metadata));
  }

  void onChangeSelectedDatasource(String option, bool? state) {
    if (selected is! Device) { Logger().w("Changed datasource on a device, where device isn't selected"); return; }
    
    var datasource = Set.from((selected as Device).dataSources);
    if (state == false)     { datasource.remove(option); }
    else if (state == true) { datasource.add(option);    }
    else { Logger().d("Warning, selected datasource with tri-state. Tri-states on datasource aren't supported"); return; }

    changeItem(device.cloneWith(dataSources: datasource));
  }

  void onChangeDeviceGeoPosition(LatLng newPosition) {
    if (selected is! Device) { Logger().w("Changed geoposition on a device, where device isn't selected"); return; }
    
    changeItem(device.cloneWith(geoPosition: newPosition));
  }

  void onChangeLinkDeviceA(Device newDevice) {
    if (selected is! Link) { Logger().w("Changed device in link, where link isn't selected"); return; }
    
    changeItem(link.cloneWith(sideA: newDevice));
  }

  void onChangeLinkDeviceB(Device newDevice) {
    if (selected is! Link) { Logger().w("Changed device in link, where link isn't selected"); return; }
    
    changeItem(link.cloneWith(sideB: newDevice));
  }

  void onChangeLinkType(LinkType type) {
    if (selected is! Link) { Logger().w("Changed link type in link, where link isn't selected"); return; }
    
    changeItem(link.cloneWith(linkType: type));
  }

  void onDeleteSelected() {
    Map<int, dynamic> items = Map.from(state.deleted.items);
    items[selected.id] = selected;

    var selectedStack = state.selectedStack..removeLast();

    // add selected to deleted
    set(deleted: state.deleted.cloneWith(items: items), selected: selectedStack);
  }

  bool isDeleted(dynamic item) {
    return state.deleted.items.containsKey(item.id);
  }

  bool get hasChanges {
    return state.changes.items.isNotEmpty && state.deleted.items.isNotEmpty;
  }

  dynamic get selected {
    dynamic changed = state.changes.items[state.selectedStack.last.id];

    // no changes have been made, return as is
    if (changed == null) {
      return state.selectedStack.last;
    }

    // has been modified, return as is
    return changed;
  }

  dynamic get selectedMerged {
    var changed = state.changes.items[state.selectedStack.last.id];

    // no changes have been made, return as is
    if (changed == null) {
      return state.selectedStack;
    }

    // has been modified, return as original+changed
    return changed.mergeWith(state.selectedStack);
  }

  Device get device {
    dynamic curr = selected;

    if (curr is! Device) {
      Logger().e("Accessed item for edit, where item isn't a Device. SelectedItem = $curr");
    }

    return curr as Device;
  }

  Device get deviceMerged {
    return device.mergeWith(state.selectedStack.last);
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
}
