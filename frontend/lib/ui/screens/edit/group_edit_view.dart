import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/components/badge_button.dart';
import 'package:network_analytics/ui/screens/edit/device_edit_view.dart';
import 'package:network_analytics/ui/screens/edit/edit_commons.dart';
import 'package:settings_ui/settings_ui.dart';

class GroupEditView extends ConsumerStatefulWidget {
  final Group group;
  final Topology topology;

  static const Icon nameIcon = Icon(Icons.label);
  static const Icon membersIcon = Icon(Icons.group);

  const GroupEditView({
    super.key,
    required this.group,
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
    final selected = ref.read(itemEditSelectionNotifier).selected;

    _nameInputController = TextEditingController(text: selected.name);
  }

  void onEditName   () => ref.read(itemEditSelectionNotifier.notifier).toggleEditingGroupName();
  void onEditMembers() => ref.read(itemEditSelectionNotifier.notifier).set(editingGroupMembers: true);

  void onContentEdit(String text) {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);
    final itemEditSelection = ref.read(itemEditSelectionNotifier);

    if (itemEditSelection.selected.name == text) { return; }

    var group = itemEditSelection.selected;
    var modified = Group(id: group.id, members: group.members, name: text, isDisplayGroup: group.isDisplayGroup);
    notifier.changeItem(modified);
  }

  void onChangedMembers(int id, bool status) {
    var item = widget.topology.items[id];
    var members = widget.group.members;

    if (status) { members.add(item); } 
    else        { members.remove(item); }

    var group = widget.group.cloneWith(members: members);

    ref.read(itemEditSelectionNotifier.notifier).changeItem(group);
  }

  AbstractSettingsTile _makeNameInput() {
    final itemEditSelection = ref.watch(itemEditSelectionNotifier); 

    var editInput = EditTextField(
      initialText: widget.group.name,
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
    List<BadgeButton> members = [];
    final notifier = ref.watch(itemEditSelectionNotifier.notifier); 

    for (var member in widget.group.members) {
      if (member is! Device && member is! Group) { continue; }

      Color backgroundColor = member is Device ? Colors.blueGrey : Colors.teal;
      TextStyle style = TextStyle(color: Colors.white);
      BadgeButton button = BadgeButton(
        backgroundColor: backgroundColor,
        text: member.name,
        textStyle: style,
        onPressed: () => {notifier.setSelected(member)}
      );
      members.add(button);
    }
    
    return SettingsTile(
      title: Text("Miembros"),
      leading: GroupEditView.membersIcon,
      trailing: makeTrailing(Wrap(children: members,), onEditMembers),
      onPressed: null
    );
  }

  Widget _makeMembersSelectionInput() {
    var itemEditSelection = ref.watch(itemEditSelectionNotifier); 

    if (!itemEditSelection.editingGroupMembers) { return SizedBox.shrink(); }

    var options = widget.topology.getDevices();
    var checkboxes = options.map((option) {
          return CheckboxListTile(
            value: widget.group.memberKeys.contains(option.id),
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
    return Column(
      children: [ Expanded( child: SettingsList( sections: [
              SettingsSection(
                title: Text(widget.group.name),
                tiles: [ _makeNameInput(), _makeMembersInput() ]
              )])),
        // Save button and cancel button
        makeFooter(ref),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
      // if item changed, reset the text fields
      ref.listen(itemEditSelectionNotifier, (previous, next) {
        if (previous?.selected != next.selected) {
          _nameInputController.text = next.selected.name;
        }
      });

      return Stack(children: [
        _makeSettingsView(),
        _makeMembersSelectionInput()
      ],);    
  }
}
