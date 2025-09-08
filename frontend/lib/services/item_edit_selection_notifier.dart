import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/topology.dart';

class ItemEditSelection {
  final dynamic selected;
  final Topology changes;
  final bool editingGroupName;
  final bool editingGroupMembers;
  final bool editingDeviceName;
  final bool editingDeviceHostname;
  final bool editingLinkIfaceA;
  final bool editingLinkIfaceB;

  const ItemEditSelection({
    required this.selected,
    required this.changes,
    required this.editingGroupName,
    required this.editingGroupMembers,
    required this.editingDeviceName,
    required this.editingDeviceHostname,
    required this.editingLinkIfaceA,
    required this.editingLinkIfaceB,
  });
}

class ItemEditSelectionNotifier extends StateNotifier<ItemEditSelection> {
  ItemEditSelectionNotifier() 
  : super(
    ItemEditSelection(
      selected: null,
      changes: Topology(items: {}, groups: []),
      editingGroupName: false,
      editingGroupMembers: false,
      editingDeviceName: false,
      editingDeviceHostname: false,
      editingLinkIfaceA: false,
      editingLinkIfaceB: false,
      )
    );

  void setSelected(dynamic selected) => 
      state = ItemEditSelection(
        selected: selected,
        changes: state.changes,
        editingGroupName: false,
        editingGroupMembers: false,
        editingDeviceName: false,
        editingDeviceHostname: false,
        editingLinkIfaceA: false,
        editingLinkIfaceB: false,
      );

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

    bool keepState = false,
  }) {
    if (keepState) {
      state = ItemEditSelection(
        selected: selected ?? state.selected,
        changes: changes ?? state.changes,
        editingGroupName      : state.editingGroupName,
        editingGroupMembers   : state.editingGroupMembers,
        editingDeviceName     : state.editingDeviceName,
        editingDeviceHostname : state.editingDeviceHostname,
        editingLinkIfaceA     : state.editingLinkIfaceA,
        editingLinkIfaceB     : state.editingLinkIfaceB,
      );
    } else {
      state = ItemEditSelection(
        selected: selected ?? state.selected,
        changes: changes ?? state.changes,
        editingGroupName      : editingGroupName,
        editingGroupMembers   : editingGroupMembers,
        editingDeviceName     : editingDeviceName,
        editingDeviceHostname : editingHostname,
        editingLinkIfaceA     : editingLinkIfaceA,
        editingLinkIfaceB     : editingLinkIfaceB,
      );
    }
  }

  void changeItem(dynamic item) {
    var topology = state.changes;
    topology.items[item.id] = item;

    set(changes: topology, keepState: true);
  }

  void discard() {
    set(changes: Topology(items: {}, groups: []));
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
}
