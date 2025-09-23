import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/link.dart';
import 'package:network_analytics/models/link_type.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/dialog_change_notifier.dart';
import 'package:network_analytics/services/item_edit_selection_notifier.dart';
import 'package:network_analytics/ui/components/dialogs/device_selection_dialog.dart';
import 'package:network_analytics/ui/screens/edit/commons/delete_section.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_commons.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_text_field.dart';
import 'package:network_analytics/ui/components/dialogs/option_dialog.dart';
import 'package:network_analytics/ui/components/list_selector.dart';
import 'package:settings_ui/settings_ui.dart';

class LinkEditView extends ConsumerStatefulWidget {
  final Topology topology;


  const LinkEditView({
    super.key,
    required this.topology, 
  });

  @override
  ConsumerState<LinkEditView> createState() => _LinkEditViewState();
}

class _LinkEditViewState extends ConsumerState<LinkEditView> {

  late TextEditingController _sideAIfaceInputController;
  late TextEditingController _sideBIfaceInputController;

  @override
  void initState() {
    super.initState();
    _sideAIfaceInputController = TextEditingController(text: ref.read(itemEditSelectionProvider.notifier).link.sideAIface);
    _sideBIfaceInputController = TextEditingController(text: ref.read(itemEditSelectionProvider.notifier).link.sideBIface);
  }

  void onEditSideAIface() => ref.read(itemEditSelectionProvider.notifier).set(editingLinkIfaceA: true);
  void onEditSideBIface() => ref.read(itemEditSelectionProvider.notifier).set(editingLinkIfaceB: true);
  void onCancelDelete()   => ref.read(itemEditSelectionProvider.notifier).set(requestedConfirmDeletion: false);
  void onConfirmedDelete()=> ref.read(itemEditSelectionProvider.notifier).onDeleteSelected();
  void onConfirmRestore() => ref.read(itemEditSelectionProvider.notifier).onRestoreSelected();

  void onRequestedDelete(){ ref.read(itemEditSelectionProvider.notifier).onRequestDeletion(); _displayDeleteConfirmDialog(); }
  void onEditSideB()      { ref.read(itemEditSelectionProvider.notifier).set(editingLinkDeviceB: true); _displaySelectionDialog(deviceB: true);}
  void onEditSideA()      { ref.read(itemEditSelectionProvider.notifier).set(editingLinkDeviceA: true); _displaySelectionDialog(deviceA: true);}

  void onEditSideAIfaceContent(String text) {
    final notifier = ref.read(itemEditSelectionProvider.notifier);
    var link = notifier.link;
  
    onEditIFaceContent(text, notifier.link.sideAIface, (text) => link.cloneWith(sideAIface: text));
  }

  void onEditSideBIfaceContent(String text) {
    final notifier = ref.read(itemEditSelectionProvider.notifier);
    var link = notifier.link;
  
    onEditIFaceContent(text, notifier.link.sideBIface, (text) => link.cloneWith(sideBIface: text));
  }

  void onEditIFaceContent(String text, String currentText, Link Function(String) modifyFn) {
    final notifier = ref.read(itemEditSelectionProvider.notifier);

    if (currentText == text) { return; }

    var modified = modifyFn(text);
    notifier.changeItem(modified);
  }

  DropdownButton _makeLinkTypeDropdown(LinkType linkType) {
    return DropdownButton<String>(
    value: linkType.name,
      hint: const Text("Link type"),
      items: LinkType.values
          .map((type) =>
              DropdownMenuItem(value: type.name, child: Text(type.name)))
          .toList(),
      onChanged: (val) {}, // TODO: Functionality
      isExpanded: true,
    );
  }

  AbstractSettingsTile _makeInterfaceInput(
    Link link,
    bool enabled,
    String startingText,
    TextEditingController inputController,
    Topology topology,
    bool Function(Topology) isModified,
    Function() onEdit,
    Function(String) onContentEdit
  ) {
    bool modified = isModified(topology);
    Color backgroundColor = modified ? addedItemColor : Colors.transparent;

    var editInput = EditTextField(
      initialText: startingText,
      enabled: enabled,
      backgroundColor: backgroundColor,
      controller: inputController,
      showEditIcon: true,
      onEditToggle: onEdit,
      onContentEdit: onContentEdit,
    );

    return SettingsTile(
      title: Text("Interface"),
      leading: const Icon(Icons.settings_ethernet),
      trailing: editInput,
    );
  }

  AbstractSettingsTile _makeInterfaceAInput(Link link, bool enabled, Topology topology) {
    return _makeInterfaceInput(link, enabled, link.sideAIface, _sideAIfaceInputController, topology, link.isModifiedAIface, onEditSideAIface, onEditSideAIfaceContent);
  }

  AbstractSettingsTile _makeInterfaceBInput(Link link, bool enabled, Topology topology) {
    return _makeInterfaceInput(link, enabled, link.sideBIface, _sideBIfaceInputController, topology, link.isModifiedBIface, onEditSideBIface, onEditSideBIfaceContent);
  }

  AbstractSettingsTile _makeDeviceSelection(String title, Device device, Device other, Function() onEdit) {
    // var child = _makeDeviceDropdown(device, other, "Select device $title");
    var child = EditTextField(enabled: false, initialText: device.name, showEditIcon: true, onEditToggle: onEdit,);

    return SettingsTile(
      title: Text(title),
      leading: const Icon(Icons.dns),
      trailing: child,
      onPressed: null
    ); 
  }

  SettingsSection _makeLinkSelection(Link link) {
    var child = _makeLinkTypeDropdown(link.linkType);

    return SettingsSection(
        title: Text("Link type"),
        tiles: [
          SettingsTile(
            title: const Text("Link Type"),
            leading: const Icon(Icons.cable),
            trailing: makeTrailing(child, (){}, showEditIcon: false),
          )
        ],
      );
  }

  SettingsSection _makeDeviceSection(String title, Link link, {required bool sideA}) {

    final itemSelection = ref.read(itemEditSelectionProvider);

    bool editingAIface = itemSelection.editingLinkIfaceA;
    bool editingBIface = itemSelection.editingLinkIfaceB;

    var makeInput = sideA ? _makeInterfaceAInput : _makeInterfaceBInput;
    var onEdit    = sideA ? onEditSideA : onEditSideB;
    Device device = sideA ? link.sideA : link.sideB;
    Device other  = sideA ? link.sideB : link.sideA;
    bool editing  = sideA ? editingAIface : editingBIface;

    return SettingsSection(
        title: Text(title),
        tiles: [
          _makeDeviceSelection("Device", device, other, onEdit),
          makeInput(link, editing , widget.topology),
        ],
      );
  }

  Future _displaySelectionDialog({bool deviceA = false, bool deviceB = false}) {
    final itemEditSelection = ref.watch(itemEditSelectionProvider); 
    final notif = ref.watch(itemEditSelectionProvider.notifier);

    bool linkType= itemEditSelection.editingLinkType;
    Link link    = notif.link;

    bool enabled = deviceA || deviceB || linkType;

    if (!enabled) { return Future.value(null); }

    getOptions(Device device) {
      Logger().d("Filtering out device with ID ${device.id}");
      return widget.topology.devices.where((item) => item.id != device.id).toSet();
    }

    Set<Device> options = {};
    if      (deviceA) { options = getOptions(link.sideB); }
    else if (deviceB) { options = getOptions(link.sideA);}
    
    bool isSelectedFn(option) {
      if      (deviceA)  { return ref.read(itemEditSelectionProvider.notifier).link.sideA == option; }
      else if (deviceB) {return ref.read(itemEditSelectionProvider.notifier).link.sideB == option; }
      
      return false;
    }

    onChanged (option, state) {
      if      (deviceA)  { notif.onChangeLinkDeviceA(option); } 
      else if (deviceB)  { notif.onChangeLinkDeviceB(option); }

      ref.read(dialogRebuildProvider.notifier).markDirty();
    }
    onClose () => notif.set(editingDeviceMetadata: false, editingDeviceMetrics: false, editingDeviceDataSources: false); 
    
    final dialog = DeviceSelectionDialog(
      options: options,
      selectorType: ListSelectorType.radio,
      onChanged: onChanged,
      onClose: onClose,
      isSelectedFn: isSelectedFn
    );


    return dialog.show(context);
  }

  void _displayDeleteConfirmDialog() {
    final itemSelection = ref.read(itemEditSelectionProvider);

    bool showConfirmDialog = itemSelection.confirmDeletion;

    if (!showConfirmDialog) { return; }

    OptionDialog(
        dialogType: OptionDialogType.cancelDelete,
        title: Text("Confirmar acción"),
        confirmMessage: Text("(Los cambios no serán apliacados todavía)"),
        onCancel: onCancelDelete,
        onDelete: onConfirmedDelete,
      ).show(context);
  }

  Widget _buildConfigurationPage() {
    final notifier = ref.read(itemEditSelectionProvider.notifier);

    Link link = notifier.link;

    var settingsList = SettingsList( sections: [
        CustomSettingsSection(child: _makeDeviceSection("Device A", link, sideA: true)),
        CustomSettingsSection(child: _makeDeviceSection("Device B", link, sideA: false)),
        CustomSettingsSection(child: _makeLinkSelection(link)),
        CustomSettingsSection(child: DeleteSection(onDelete: onRequestedDelete, onRestore: onConfirmRestore)),
      ],);

    return Column(
      children: [ Expanded( child: settingsList),
        // Save button and cancel button
        makeFooter(ref, widget.topology),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {

    // if item changed, reset the text fields
    ref.listen(itemEditSelectionProvider, (previous, next) {
      if (previous?.selectedStack != next.selectedStack && next.selectedStack is Link) {
        _sideAIfaceInputController.text = (next.selectedStack.last as Link).sideAIface;
        _sideBIfaceInputController.text = (next.selectedStack.last as Link).sideBIface;
      }
    });

    return _buildConfigurationPage();
  }
}