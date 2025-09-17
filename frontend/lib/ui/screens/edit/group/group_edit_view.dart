import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/components/badge_button.dart';
import 'package:network_analytics/ui/screens/edit/commons/delete_section.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_text_field.dart';
import 'package:network_analytics/ui/screens/edit/commons/option_dialog.dart';
import 'package:network_analytics/ui/screens/edit/commons/select_dialog.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_commons.dart';
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
    final selected = ref.read(itemEditSelectionNotifier.notifier).group;

    _nameInputController = TextEditingController(text: selected.name);
  }

  void onEditName   ()       => ref.read(itemEditSelectionNotifier.notifier).toggleEditingGroupName();
  void onEditMembers()       => ref.read(itemEditSelectionNotifier.notifier).set(editingGroupMembers: true);
  void onRequestedDelete()   => ref.read(itemEditSelectionNotifier.notifier).onRequestDeletion();
  void onCancelDelete()      => ref.read(itemEditSelectionNotifier.notifier).set(requestedConfirmDeletion: false);
  void onConfirmedDelete()   => ref.read(itemEditSelectionNotifier.notifier).onDeleteSelected();
  void onConfirmRestore()    => ref.read(itemEditSelectionNotifier.notifier).onRestoreSelected();

  void onContentEdit(String text) {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);

    if (notifier.group.name == text) { return; }

    var group = notifier.group;
    var modified = group.cloneWith(name: text);
    notifier.changeItem(modified);
  }

  void onChangedMembers(int id, bool status) {
    final notifier = ref.watch(itemEditSelectionNotifier.notifier);

    var item = widget.topology.items[id];
    var members = Set.from(notifier.group.members);

    if (status) { members.add(item); } 
    else        { members.remove(item); }

    Logger().d("Changed members of Group, id=$id, status=$status, members=$members");

    var group = notifier.group.cloneWith(members: members);

    ref.read(itemEditSelectionNotifier.notifier).changeItem(group);
  }

  AbstractSettingsTile _makeNameInput(Group group, bool enabled, Topology topology) {
    
    bool modified = group.isModifiedName(topology);
    Color backgroundColor = modified ? addedItemColor : Colors.transparent;


    var editInput = EditTextField(
      initialText: group.name,
      enabled: enabled,
      backgroundColor: backgroundColor,
      controller: _nameInputController,
      showEditIcon: true,
      onEditToggle: onEditName,
      onContentEdit: onContentEdit,
    );


    return SettingsTile(
      title: Text("Nombre"), leading: GroupEditView.nameIcon, trailing: editInput, onPressed: null
    );
  }

  AbstractSettingsTile _makeMembersInput() {
    List<BadgeButton> list = [];
    final notifier = ref.watch(itemEditSelectionNotifier.notifier); 

    for (var member in notifier.group.members) {
      if (member is! Device && member is! Group) { continue; }

      Color backgroundColor = member is Device ? Colors.blueGrey : Colors.teal;
      TextStyle style = TextStyle(color: Colors.white);
      BadgeButton button = BadgeButton(
        backgroundColor: backgroundColor,
        text: member.name,
        textStyle: style,
        onPressed: () => {notifier.setSelected(member, appendState: true)}
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

  Widget _buildMembersSelectionInput() {
    var itemEditSelection = ref.watch(itemEditSelectionNotifier); 
    final notifier = ref.watch(itemEditSelectionNotifier.notifier);
    if (!itemEditSelection.editingGroupMembers) { return SizedBox.shrink(); }

    
    var options = widget.topology.getDevices().toSet();

    isSelectedFn(option) => notifier.group.memberKeys.contains(option.id);
    onChanged(option, state) => onChangedMembers(option.id, state ?? false);
    onClose() => notifier.set(editingGroupMembers: false);
    toText(device) => (device as Device).name;
    
    return SelectDialog(
      options: options,
      dialogType: SelectDialogType.checkbox,
      isSelectedFn: isSelectedFn,
      onChanged: onChanged,
      onClose: onClose,
      toText: toText,
    );
  }

  Widget _makeDeleteSection() {
    return DeleteSection(onDelete: onRequestedDelete, onRestore: onConfirmRestore);
  }


  Widget _buildSettingsView() {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);
    final itemSelection = ref.read(itemEditSelectionNotifier);

    Group group = notifier.group;
    bool editingName = itemSelection.editingGroupName;

    return Column(
      children: [ Expanded( child: SettingsList( sections: [
              SettingsSection(
                title: Text(notifier.group.name),
                tiles: [ 
                  _makeNameInput(group, editingName, widget.topology),
                  _makeMembersInput(),
                ]
              ),
              CustomSettingsSection(child: _makeDeleteSection(),)
              ])),
        // Save button and cancel button
        makeFooter(ref, widget.topology),
      ],
    );
  }

  Widget _buildDeleteConfirmDialog() {
    final itemSelection = ref.read(itemEditSelectionNotifier);

    bool showConfirmDialog = itemSelection.confirmDeletion;

    if (!showConfirmDialog) { return SizedBox.shrink(); }

    return OptionDialog(
        dialogType: OptionDialogType.cancelDelete,
        title: Text("Confirmar acción"),
        confirmMessage: Text("(Los cambios no serán apliacados todavía)"),
        onCancel: onCancelDelete,
        onDelete: onConfirmedDelete,
      );
  }

  @override
  Widget build(BuildContext context) {
      // if item changed, reset the text fields
      ref.listen(itemEditSelectionNotifier, (previous, next) {
        if (previous?.selectedStack != next.selectedStack && next.selectedStack.last is Group) {
          _nameInputController.text = (next.selectedStack.last as Group).name;
        }
      });

      return Stack(children: [
        _buildSettingsView(),
        _buildMembersSelectionInput(),
        _buildDeleteConfirmDialog(),
      ],);    
  }
}
