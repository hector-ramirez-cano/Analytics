import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/link.dart';
import 'package:network_analytics/models/link_type.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/providers/providers.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_commons.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_text_field.dart';
import 'package:network_analytics/ui/screens/edit/commons/option_dialog.dart';
import 'package:network_analytics/ui/screens/edit/commons/select_dialog.dart';
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
    _sideAIfaceInputController = TextEditingController(text: ref.read(itemEditSelectionNotifier.notifier).link.sideAIface);
    _sideBIfaceInputController = TextEditingController(text: ref.read(itemEditSelectionNotifier.notifier).link.sideBIface);
  }

  void onEditSideAIface() => ref.read(itemEditSelectionNotifier.notifier).set(editingLinkIfaceA: true);
  void onEditSideBIface() => ref.read(itemEditSelectionNotifier.notifier).set(editingLinkIfaceB: true);
  void onEditSideA()      => ref.read(itemEditSelectionNotifier.notifier).set(editingLinkDeviceA: true);
  void onEditSideB()      => ref.read(itemEditSelectionNotifier.notifier).set(editingLinkDeviceB: true);
  void onRequestedDelete()=> ref.read(itemEditSelectionNotifier.notifier).onRequestDeletion();
  void onCancelDelete()   => ref.read(itemEditSelectionNotifier.notifier).set(requestedConfirmDeletion: false);
  void onConfirmedDelete()=> ref.read(itemEditSelectionNotifier.notifier).onDeleteSelected();

  void onEditSideAIfaceContent(String text) {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);
    var link = notifier.link;
  
    onEditIFaceContent(text, notifier.link.sideAIface, (text) => link.cloneWith(sideAIface: text));
  }

  void onEditSideBIfaceContent(String text) {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);
    var link = notifier.link;
  
    onEditIFaceContent(text, notifier.link.sideBIface, (text) => link.cloneWith(sideBIface: text));
  }

  void onEditIFaceContent(String text, String currentText, Link Function(String) modifyFn) {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);

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

    final itemSelection = ref.read(itemEditSelectionNotifier);

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

  SettingsSection _makeDeleteSection() {
    resolveColor (states) {
      if (states.contains(WidgetState.hovered)) {
        return const Color.fromRGBO(226, 71, 71, 1);
      } 
      return Colors.blueGrey;
    }

    return SettingsSection(
      title: Text(""), tiles: [
        SettingsTile(title: SizedBox(
          width: double.infinity, 
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            child: ElevatedButton(
              style: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(Colors.white),
                backgroundColor: WidgetStateProperty.resolveWith<Color?>(resolveColor)
              ),
              onPressed: onRequestedDelete,
              child: const Text("Eliminar", ),
            ),
          ),))
      ]
    );
  }


  Widget _buildSelectionDialog() {
    final itemEditSelection = ref.watch(itemEditSelectionNotifier); 
    final notif = ref.watch(itemEditSelectionNotifier.notifier);

    bool deviceA = itemEditSelection.editingLinkDeviceA;
    bool deviceB = itemEditSelection.editingLinkDeviceB;
    bool linkType= itemEditSelection.editingLinkType;
    Link link    = notif.link;

    bool enabled = deviceA || deviceB || linkType;

    if (!enabled) { return SizedBox.shrink(); }

    getOptions(Device device) {
      Logger().d("Filtering out device with ID ${device.id}");
      return widget.topology.getDevices().where((item) => item.id != device.id).toSet();
    }

    Set<Device> selectedOptions;
    Set<Device> options;
    if (deviceA)  { 
      Logger().d("Input for device A");
      selectedOptions = {link.sideA};
      options = getOptions(link.sideB);
    }
    else if (deviceB) {
      Logger().d("Input for device B");
      selectedOptions = {link.sideB};
      options = getOptions(link.sideA);
    }
    else {
      return SizedBox.shrink();
    }

    onChanged (option, state) => {
      if      (deviceA)  { notif.onChangeLinkDeviceA(option) } 
      else if (deviceB)  { notif.onChangeLinkDeviceB(option) }
      else {
        throw Exception("Unreachable code reached! Logic is faulty!")
      }
    }; 
    isSelectedFn (option) => selectedOptions.contains(option);
    onClose () => notif.set(editingDeviceMetadata: false, editingDeviceMetrics: false, editingDeviceDataSources: false); 
    toText(option) => (option as Device).name;

    return SelectDialog(
      options: options,
      dialogType: SelectDialogType.radio,
      isSelectedFn: isSelectedFn,
      onChanged: onChanged,
      onClose: onClose,
      toText: toText,
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


  Widget _buildConfigurationPage() {
    final notifier = ref.read(itemEditSelectionNotifier.notifier);

    Link link = notifier.link;

    return Column(
      children: [ Expanded( child: SettingsList( sections: [
              CustomSettingsSection(child: _makeDeviceSection("Device A", link, sideA: true)),
              CustomSettingsSection(child: _makeDeviceSection("Device B", link, sideA: false)),
              CustomSettingsSection(child: _makeLinkSelection(link)),
              CustomSettingsSection(child: _makeDeleteSection()),
            ],),),
        // Save button and cancel button
        makeFooter(ref, widget.topology),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {

    // if item changed, reset the text fields
      ref.listen(itemEditSelectionNotifier, (previous, next) {
        if (previous?.selectedStack != next.selectedStack && next.selectedStack is Link) {
          _sideAIfaceInputController.text = (next.selectedStack.last as Link).sideAIface;
          _sideBIfaceInputController.text = (next.selectedStack.last as Link).sideBIface;
        }
      });

    return Stack(
      children: [
        _buildConfigurationPage(),
        _buildSelectionDialog(),
        _buildDeleteConfirmDialog(),
      ],
    );
  }
}