import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/models/alerts/alert_rule.dart';
import 'package:network_analytics/models/analytics_item.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/link.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/item_edit_selection_notifier.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_commons.dart';
import 'package:settings_ui/settings_ui.dart';

class NewEditView extends StatefulWidget {
  final Topology topology;
  
  const NewEditView({
    super.key,
    required this.topology
  });

  @override
  State<NewEditView> createState() => _NewEditViewState();
}

class _NewEditViewState extends State<NewEditView> {
  String selected = "Dispositivo";

  void _onTypeChange(String val) {
    setState(() {
      selected = val;
    });
  }

  void _onCreate(WidgetRef ref) {
    AnalyticsItem item;
    final notifier = ref.read(itemEditSelectionProvider.notifier);
    switch (selected) {
      case "Dispositivo":
        item = Device.empty();
        break;

      case "Link":
        item = Link.empty();

      case "Grupo":
        item = Group.empty();

      case "Regla de alerta":
        item = AlertRule.empty();

      default:
        throw Exception("Unreachable code reached!");
    }
    notifier.set(overrideCreatingItem: true);
    notifier.setSelected(item, appendToTopology: true);
  }

  void _onCancel(WidgetRef ref) {
    ref.read(itemEditSelectionProvider.notifier).set(overrideCreatingItem: false);
  }

  Widget _makeCreateButton() {
    return Consumer(builder:(context, ref, child) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(onPressed: () => _onCreate(ref), child: Text("Crear")),
      );
    });
  }

  Widget _makeCancelButton() {
    return Consumer(builder:(context, ref, child) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(onPressed: () => _onCancel(ref), style: ButtonStyle(overlayColor: WidgetStateProperty.all(const Color.fromRGBO(255, 181, 176, 1))), child: Text("Cancelar"),),
      );
    });
  }

  SettingsSection _makeItemTypeSection() {
    var child = DropdownButton<String>(
      value: selected,
        hint: const Text("Tipo"),
        items: ["Dispositivo", "Link", "Grupo", "Regla de alerta"]
            .map((type) =>
                DropdownMenuItem(value: type, child: Text(type)))
            .toList(),
        onChanged: (val) => _onTypeChange(val!),
        isExpanded: true,
      );

    return SettingsSection(
        title: Text("Tipo"),
        tiles: [
          SettingsTile(
            title: const Text("Tipo"),
            leading: const Icon(Icons.dns),
            trailing: makeTrailing(child, (){}, showEditIcon: false),
          )
        ],
      );
  }

  Widget _buildConfigurationPage() {
    return SettingsList( sections: [
            _makeItemTypeSection(),
            CustomSettingsSection(child: _makeCreateButton()),
            CustomSettingsSection(child: _makeCancelButton()),
          ],
        );
  }

  @override
  Widget build(BuildContext context) {
    return _buildConfigurationPage();
  }}