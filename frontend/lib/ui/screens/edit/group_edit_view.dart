import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/components/badge_button.dart';
import 'package:network_analytics/ui/screens/edit/checkbox_select_dialog.dart';
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
    var modified = group.cloneWith(name: text);
    notifier.changeItem(modified);
  }

  void onChangedMembers(int id, bool status) {
    final notifier = ref.watch(itemEditSelectionNotifier.notifier);

    var item = widget.topology.items[id];
    var members = List.from(notifier.selected.members);

    if (status) { members.add(item); } 
    else        { members.remove(item); }

    Logger().d("Changed members of Group, id=$id, status=$status, members=$members");

    var group = notifier.selected.cloneWith(members: members);

    ref.read(itemEditSelectionNotifier.notifier).changeItem(group);
  }

  AbstractSettingsTile _makeNameInput() {
    final itemEditSelection = ref.watch(itemEditSelectionNotifier); 
    final notifier = ref.watch(itemEditSelectionNotifier.notifier);

    var editInput = EditTextField(
      initialText: notifier.selected.name,
      enabled: itemEditSelection.editingGroupName,
      controller: _nameInputController,
      showEditIcon: true,
      onEditToggle: onEditName,
      onContentEdit: onContentEdit,
    );


    return SettingsTile(
      title: Text("Nombre"), leading: DeviceEditView.nameIcon, trailing: editInput, onPressed: null
    );
  }

  AbstractSettingsTile _makeMembersInput() {
    List<BadgeButton> list = [];
    final notifier = ref.watch(itemEditSelectionNotifier.notifier); 

    for (var member in notifier.selected.members) {
      if (member is! Device && member is! Group) { continue; }

      Color backgroundColor = member is Device ? Colors.blueGrey : Colors.teal;
      TextStyle style = TextStyle(color: Colors.white);
      BadgeButton button = BadgeButton(
        backgroundColor: backgroundColor,
        text: member.name,
        textStyle: style,
        onPressed: () => {notifier.setSelected(member)}
      );
      list.add(button);
    }
    
    var members = Wrap(spacing: 4, runSpacing: 4,children: list,);

    return SettingsTile(
      title: Text("Miembros"),
      leading: GroupEditView.membersIcon,
      trailing: makeTrailing(members, onEditMembers),
      onPressed: null
    );
  }

  Widget _makeMembersSelectionInput() {
    var itemEditSelection = ref.watch(itemEditSelectionNotifier); 
    final notifier = ref.watch(itemEditSelectionNotifier.notifier);
    if (!itemEditSelection.editingGroupMembers) { return SizedBox.shrink(); }

    
    var options = widget.topology.getDevices().toSet();

    isSelected(option) => notifier.selected.memberKeys.contains(option.id);
    onChanged(option, state) => onChangedMembers(option.id, state ?? false);
    onClose() => notifier.set(editingGroupMembers: false);
    toText(device) => (device as Device).name;
    
    return CheckboxSelectDialog(options: options, isSelected: isSelected, onChanged: onChanged, onClose: onClose, toText: toText,);
  }

  Widget _makeSettingsView() {
    final notifier = ref.watch(itemEditSelectionNotifier.notifier);
    return Column(
      children: [ Expanded( child: SettingsList( sections: [
              SettingsSection(
                title: Text(notifier.selected.name),
                tiles: [ _makeNameInput(), _makeMembersInput() ]
              )])),
        // Save button and cancel button
        makeFooter(ref, widget.topology),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
      // if item changed, reset the text fields
      ref.listen(itemEditSelectionNotifier, (previous, next) {
        if (previous?.selected != next.selected && next.selected != null) {
          _nameInputController.text = next.selected.name;
        }
      });

      return Stack(children: [
        _makeSettingsView(),
        _makeMembersSelectionInput()
      ],);    
  }
}
