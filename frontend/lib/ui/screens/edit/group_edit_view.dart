import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/screens/edit/device_edit_view.dart';
import 'package:network_analytics/ui/screens/edit/edit_commons.dart';
import 'package:settings_ui/settings_ui.dart';

class GroupEditView extends ConsumerStatefulWidget {
  final Topology topology;

  static const Icon nameIcon = Icon(Icons.label);
  static const Icon membersIcon = Icon(Icons.group);

  const GroupEditView({
    super.key,
    required this.topology,
  });

  @override
  ConsumerState<GroupEditView> createState() => _GroupEditViewState();
}

class _GroupEditViewState extends ConsumerState<GroupEditView> {
  late TextEditingController _nameInputController;

  @override
  void initState() {
    super.initState();
    _nameInputController = TextEditingController(text: ref.read(itemEditSelectionNotifier).selected.name);
  }

  void onEditName   () => ref.read(itemEditSelectionNotifier.notifier).toggleEditingGroupName();
  void onEditMembers() => ref.read(itemEditSelectionNotifier.notifier).setEditingGroupMembers(true);

  void onContentEdit(String text) {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);
    final itemEditSelection = ref.read(itemEditSelectionNotifier);

    if (itemEditSelection.selected.name == text) { return; }

    var group = itemEditSelection.selected;
    var modified = Group(id: group.id, members: group.members, name: text, isDisplayGroup: group.isDisplayGroup);
    notifier.changeItem(modified);
  }

  void onChangedMembers(int id, bool status) {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);

    var item = widget.topology.items[id];
    var members = notifier.selected.members;

    if (status) { members.add(item); } 
    else        { members.remove(item); }

    var group = notifier.selected.cloneWith(members: members);

    ref.read(itemEditSelectionNotifier.notifier).changeItem(group);
  }

  AbstractSettingsTile _makeNameInput() {
    final itemEditSelection = ref.watch(itemEditSelectionNotifier); 
    final notifier = ref.read(itemEditSelectionNotifier.notifier);

    var editInput = EditTextField(
      initialText: notifier.selected.name,
      enabled: itemEditSelection.editingGroupName,
      controller: _nameInputController,
      showEditIcon: true,
      onEditToggle: onEditName,
      onContentEdit: onContentEdit,
    );


    return SettingsTile(
      title: Text("Nombre"),
      leading: DeviceEditView.nameIcon,
      trailing: editInput,
      onPressed: null
    );
  }

  AbstractSettingsTile _makeMembersInput() {
    return SettingsTile(
      title: Text("Miembros"),
      leading: GroupEditView.membersIcon,
      trailing: makeTrailing(Text(""), onEditMembers),
      onPressed: null
    );
  }

  Widget _makeMembersSelectionInput() {
    var itemEditSelection = ref.watch(itemEditSelectionNotifier); 
    var notifier = ref.read(itemEditSelectionNotifier.notifier);

    if (!itemEditSelection.editingGroupMembers) { return SizedBox.shrink(); }

    var options = widget.topology.getDevices();
    var checkboxes = options.map((option) {
          return CheckboxListTile(
            value: notifier.selected.memberKeys.contains(option.id),
            onChanged: (state) => onChangedMembers(option.id, state ?? false),
            title: Text(option.name),
          );
        }).toList();

    return Container(
      color: Color.fromRGBO(100, 100, 100, 0.5),
        child: Padding(
          padding: EdgeInsetsGeometry.directional(start: 50, end: 50, top: 50, bottom: 150),
          child: Container(
            color: Colors.white,
            child: Column(children: checkboxes),
          )
        ),
    );
  }

  Widget _makeSettingsView() {
    var notifier = ref.read(itemEditSelectionNotifier.notifier);
    return Column(
      children: [ Expanded( child: SettingsList( sections: [
              SettingsSection(
                title: Text(notifier.selected.name),
                tiles: [ _makeNameInput(), _makeMembersInput() ]
              )])),
        // Save button and cancel button
        makeFooter(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer (builder:
      (context, ref, child) {
        return Stack(children: [
          _makeSettingsView(),
          _makeMembersSelectionInput()
        ],);
    });
  }
}
