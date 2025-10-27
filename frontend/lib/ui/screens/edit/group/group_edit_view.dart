import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/models/analytics_item.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/dialog_change_notifier.dart';
import 'package:network_analytics/services/item_edit_selection_notifier.dart';
import 'package:network_analytics/ui/components/badge_button.dart';
import 'package:network_analytics/ui/components/dialogs/groupable_item_selection_dialog.dart';
import 'package:network_analytics/ui/screens/edit/commons/delete_section.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_text_field.dart';
import 'package:network_analytics/ui/components/list_selector.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_commons.dart';
import 'package:settings_ui/settings_ui.dart';

class GroupEditView extends ConsumerStatefulWidget {
  final Topology topology;

  final bool showDeleteButton;

  static const Icon nameIcon = Icon(Icons.label);
  static const Icon membersIcon = Icon(Icons.group);

  const GroupEditView({
    super.key,
    required this.topology,
    required this.showDeleteButton
  });

  @override
  ConsumerState<GroupEditView> createState() => _GroupEditViewState();
}

class _GroupEditViewState extends ConsumerState<GroupEditView> {
  late TextEditingController _nameInputController;

  @override
  void initState() {
    super.initState();
    final selected = ref.read(itemEditSelectionProvider.notifier).group;

    _nameInputController = TextEditingController(text: selected.name);
  }

  // Callbacks that change the state
  void onEditName   ()       => ref.read(itemEditSelectionProvider.notifier).toggleEditingGroupName();
  void onConfirmRestore()    => ref.read(itemEditSelectionProvider.notifier).onRestoreSelected();

  // Callbacks that display a dialog and change the state
  void onEditMembers()       { ref.read(itemEditSelectionProvider.notifier).set(editingGroupMembers: true); _displayMembersSelectionInput();}
  void onRequestedDelete()   { ref.read(itemEditSelectionProvider.notifier).onRequestDeletion(); displayDeleteConfirmDialog(context, ref); }

  void onContentEdit(String text) {
    final notifier = ref.read(itemEditSelectionProvider.notifier);

    if (notifier.group.name == text) { return; }

    var group = notifier.group;
    var modified = group.copyWith(name: text);
    notifier.changeItem(modified);
  }

  void onChangedMembers(int id, bool status) {
    final notifier = ref.watch(itemEditSelectionProvider.notifier);

    var item = widget.topology.items[id];
    var members = Set<GroupableItem>.from(notifier.group.members);

    if (status) { members.add(item); }
    else        { members.remove(item); }

    Logger().d("Changed members of Group, id=$id, status=$status, members=$members");

    var group = notifier.group.copyWith(members: members);

    ref.read(itemEditSelectionProvider.notifier).changeItem(group);
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
    final notifier = ref.watch(itemEditSelectionProvider.notifier);

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

  void _displayMembersSelectionInput() {
    var itemEditSelection = ref.watch(itemEditSelectionProvider);
    final notifier = ref.watch(itemEditSelectionProvider.notifier);
    if (!itemEditSelection.editingGroupMembers) { return; }

    Set<GroupableItem> options = notifier.group.memberCandidates(widget.topology);

    isSelectedFn(option) => notifier.group.memberKeys.contains(option.id);
    onClose() => notifier.set(editingGroupMembers: false);
    onChanged(option, state) {
      onChangedMembers(option.id, state ?? false);
      ref.watch(dialogRebuildProvider.notifier).markDirty();
    }

    GroupableItemSelectionDialog(
      options: options,
      selectorType: ListSelectorType.checkbox,
      onChanged: onChanged,
      onClose: onClose,
      isSelectedFn: isSelectedFn,
      isAvailable: (_) => true
    ).show(context);
  }

  Widget _makeDeleteSection() {
    return DeleteSection(onDelete: onRequestedDelete, onRestore: onConfirmRestore);
  }

  Widget _buildSettingsView() {
    final notifier = ref.read(itemEditSelectionProvider.notifier);
    final itemSelection = ref.read(itemEditSelectionProvider);

    Group group = notifier.group;
    bool editingName = itemSelection.editingGroupName;

    final List<AbstractSettingsSection> sections = [
      SettingsSection(
        title: Text(notifier.group.name),
        tiles: [
          _makeNameInput(group, editingName, widget.topology),
          _makeMembersInput(),
        ]),];
    
    if (widget.showDeleteButton) {
      sections.add(CustomSettingsSection(child: _makeDeleteSection(),));
    }

    return Column(
      children: [ Expanded( child: SettingsList( sections: sections)),
        // Save button and cancel button
        makeFooter(ref, widget.topology),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
      // if item changed, reset the text fields
      ref.listen(itemEditSelectionProvider, (previous, next) {
        if (previous?.selectedStack != next.selectedStack && next.selectedStack.isNotEmpty && next.selectedStack.last is Group) {
          _nameInputController.text = (next.selectedStack.last as Group).name;
        }
      });

      return _buildSettingsView();
  }
}
