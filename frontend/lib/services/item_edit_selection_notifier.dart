import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_map/free_map.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/link.dart';
import 'package:network_analytics/models/topology.dart';

class ItemEditSelection {
  final dynamic selected;
  final Topology changes;
  final bool editingGroupName;
  final bool editingGroupMembers;
  final bool editingLinkIfaceA;
  final bool editingLinkIfaceB;
  final bool editingDeviceName;
  final bool editingDeviceHostname;
  final bool editingDeviceMetadata;
  final bool editingDeviceMetrics;
  final bool editingDeviceDataSources;
  final bool editingDeviceGeoPosition;
  

  const ItemEditSelection({
    required this.selected,
    required this.changes,
    required this.editingGroupName,
    required this.editingGroupMembers,
    required this.editingDeviceName,
    required this.editingLinkIfaceB,
    required this.editingLinkIfaceA,
    required this.editingDeviceHostname,
    required this.editingDeviceMetadata,
    required this.editingDeviceMetrics,
    required this.editingDeviceDataSources,
    required this.editingDeviceGeoPosition,
  });
}

class ItemEditSelectionNotifier extends StateNotifier<ItemEditSelection> {
  ItemEditSelectionNotifier() 
  : super(
    ItemEditSelection(
      selected: null,
      changes: Topology(items: {}),
      editingGroupName: false,
      editingGroupMembers: false,
      editingDeviceName: false,
      editingDeviceHostname: false,
      editingLinkIfaceA: false,
      editingLinkIfaceB: false,
      editingDeviceMetadata: false,
      editingDeviceMetrics: false,
      editingDeviceDataSources: false,
      editingDeviceGeoPosition: false,
      )
    );

  void setSelected(dynamic selected) =>  set(selected: selected.cloneWith());

  bool toggleEditingGroupName() {
    bool editing = !state.editingGroupName;
    set(editingGroupName: editing);

    return editing;
  }

  void set({
    dynamic selected,
    Topology? changes,
    bool editingGroupMembers = false,
    bool editingGroupName = false,
    bool editingDeviceName = false,
    bool editingHostname = false,
    bool editingLinkIfaceA = false,
    bool editingLinkIfaceB = false,
    bool editingDeviceMetadata = false,
    bool editingDeviceMetrics = false,
    bool editingDeviceGeoPosition = false,
    bool editingDeviceDataSources = false,

    bool keepState = false,
  }) {
    if (keepState) {
      state = ItemEditSelection(
        selected              : selected ?? state.selected,
        changes               : changes ?? state.changes,
        editingGroupName      : state.editingGroupName,
        editingGroupMembers   : state.editingGroupMembers,
        editingDeviceName     : state.editingDeviceName,
        editingDeviceHostname : state.editingDeviceHostname,
        editingLinkIfaceA     : state.editingLinkIfaceA,
        editingLinkIfaceB     : state.editingLinkIfaceB,
        editingDeviceMetadata : state.editingDeviceMetadata,
        editingDeviceMetrics  : state.editingDeviceMetrics,
        editingDeviceDataSources: state.editingDeviceDataSources,
        editingDeviceGeoPosition: state.editingDeviceGeoPosition,
      );
    } else {
      state = ItemEditSelection(
        selected              : selected ?? state.selected,
        changes               : changes ?? state.changes,
        editingGroupName      : editingGroupName,
        editingGroupMembers   : editingGroupMembers,
        editingDeviceName     : editingDeviceName,
        editingDeviceHostname : editingHostname,
        editingLinkIfaceA     : editingLinkIfaceA,
        editingLinkIfaceB     : editingLinkIfaceB,
        editingDeviceMetadata : editingDeviceMetadata,
        editingDeviceMetrics  : editingDeviceMetrics,
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
    state = ItemEditSelection(
        selected              : null,
        changes               : Topology(items: {}),
        editingGroupName      : state.editingGroupName,
        editingGroupMembers   : state.editingGroupMembers,
        editingDeviceName     : state.editingDeviceName,
        editingDeviceHostname : state.editingDeviceHostname,
        editingLinkIfaceA     : state.editingLinkIfaceA,
        editingLinkIfaceB     : state.editingLinkIfaceB,
        editingDeviceMetadata : state.editingDeviceMetadata,
        editingDeviceMetrics  : state.editingDeviceMetrics,
        editingDeviceDataSources: state.editingDeviceDataSources,
        editingDeviceGeoPosition: state.editingDeviceGeoPosition,
      );
  }

  void onEditDeviceHostname()    => set(editingHostname: true);
  void onEditDeviceName()        => set(editingDeviceName: true);
  void onEditDeviceGeoposition() => set(editingDeviceGeoPosition: true);
  void onEditMetadata()          => set(editingDeviceMetadata: true);
  void onEditMetrics()           => set(editingDeviceMetrics: true);
  void onEditDataSources()       => set(editingDeviceDataSources: true);

  void onChangeDeviceMgmtHostname(String text) {
    if (selected is! Device || selected.name == text) { return; }

    var device = selected;
    var modified = device.cloneWith(mgmtHostname: text);
    changeItem(modified);
  }

  void onChangeDeviceNameContent(String text) {
    if (selected is! Device || selected.name == text) { return; }

    var device = selected;
    var modified = device.cloneWith(name: text);
    changeItem(modified);
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
    
    Device dev = device;
    changeItem(dev.cloneWith(geoPosition: newPosition));
  }

  bool get hasChanges {
    return state.changes.items.isNotEmpty;
  }

  dynamic get selected {
    var changed = state.changes.items[state.selected.id];

    // no changes have been made, return as is
    if (changed == null) {
      return state.selected;
    }

    // has been modified, return as modified
    return changed;
  }

  Device get device {
    dynamic curr = selected;

    if (curr is! Device) {
      Logger().e("Accessed item for edit, where item isn't a Device. SelectedItem = $curr");
    }

    return curr as Device;
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
