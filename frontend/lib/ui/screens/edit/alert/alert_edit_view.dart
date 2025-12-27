import 'package:aegis/models/alerts/alert_rule_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aegis/models/alerts/alert_predicate.dart';
import 'package:aegis/models/alerts/alert_reduce_logic.dart';
import 'package:aegis/models/alerts/alert_rule.dart';
import 'package:aegis/models/alerts/alert_severity.dart';
import 'package:aegis/models/alerts/alert_source.dart';
import 'package:aegis/models/analytics_item.dart';
import 'package:aegis/models/topology.dart';
import 'package:aegis/services/alerts/alert_rules_service.dart';
import 'package:aegis/services/dialog_change_notifier.dart';
import 'package:aegis/services/item_edit_selection_notifier.dart';
import 'package:aegis/ui/components/alert_rule_edit_predicate.dart';
import 'package:aegis/ui/components/badge_button.dart';
import 'package:aegis/ui/components/dialogs/empty_dialog.dart';
import 'package:aegis/ui/components/dialogs/groupable_item_selection_dialog.dart';
import 'package:aegis/ui/components/list_selector.dart';
import 'package:aegis/ui/screens/edit/commons/delete_section.dart';
import 'package:aegis/ui/screens/edit/commons/edit_commons.dart';
import 'package:aegis/ui/screens/edit/commons/edit_text_field.dart';
import 'package:settings_ui/settings_ui.dart';

class AlertEditView extends ConsumerStatefulWidget {
  final Topology topology;
  final AlertRuleSet ruleSet;
  final bool showDeleteButton;

  static const Icon nameIcon = Icon(Icons.label);
  static const Icon membersIcon = Icon(Icons.group);

  static const Map<AlertSeverity, Icon> severityIcons = {
    AlertSeverity.emergency: Icon(Icons.dangerous    , color: Colors.red  ),
    AlertSeverity.alert    : Icon(Icons.priority_high, color: Colors.red  ),
    AlertSeverity.critical : Icon(Icons.warning_amber, color: Colors.red  ),
    AlertSeverity.error    : Icon(Icons.error        , color: Colors.red  ),
    AlertSeverity.warning  : Icon(Icons.warning      , color: Colors.orange),
    AlertSeverity.notice   : Icon(Icons.notifications, color: Colors.amber),
    AlertSeverity.info     : Icon(Icons.info         , color: Colors.blue ),
    AlertSeverity.debug    : Icon(Icons.bug_report   , color: Colors.green),
    AlertSeverity.unknown  : Icon(Icons.help_outline , color: Colors.grey ),
  };

  static const Map<AlertRuleType, Icon> ruleTypeIcons = {
    AlertRuleType.simple    : Icon(Icons.looks_one), 
    AlertRuleType.delta     : Icon(Icons.swap_vert),
    AlertRuleType.sustained : Icon(Icons.timer    ),
  };

  static const Map<AlertReduceLogic, Icon> reduceLogicIcons = {
    AlertReduceLogic.all     : Icon(Icons.checklist),
    AlertReduceLogic.any     : Icon(Icons.playlist_add_check),
    AlertReduceLogic.unknown : Icon(Icons.help_outline)
  };

  static const Map<AlertSource, Icon> sourceIcons = {
    AlertSource.syslog : Icon(Icons.terminal),
    AlertSource.facts  : Icon(Icons.sensors),
    AlertSource.unknown: Icon(Icons.help_outline),
  };
  const AlertEditView({
    super.key,
    required this.topology,
    required this.ruleSet,
    required this.showDeleteButton,
  });

  @override
  ConsumerState<AlertEditView> createState() => _AlertEditViewState();
}

class _AlertEditViewState extends ConsumerState<AlertEditView> {
  late TextEditingController _nameInputController;
  late TextEditingController _sustainedSecondsInputController;

  @override
  void initState() {
    super.initState();
    final selected = ref.read(itemEditSelectionProvider.notifier).alertRule;

    _nameInputController = TextEditingController(text: selected.name);
    _sustainedSecondsInputController = TextEditingController(text: selected.sustainedTimerSeconds.toString());
  }

  // Callbacks that change the state
  void onEditName   ()       => ref.read(itemEditSelectionProvider.notifier).toggleEditingAlertName();
  void onCancelDelete()      => ref.read(itemEditSelectionProvider.notifier).set(requestedConfirmDeletion: false);
  void onConfirmedDelete()   => ref.read(itemEditSelectionProvider.notifier).onDeleteSelected();
  void onConfirmRestore()    => ref.read(itemEditSelectionProvider.notifier).onRestoreSelected();
  void onEditSustainedTimer(int t)=> ref.read(itemEditSelectionProvider.notifier).setSustainedTimer(t);
  void onSetRuleType (AlertRuleType t)=> ref.read(itemEditSelectionProvider.notifier).setRuleType(t);
  void onToggleRequiresAckInput(bool state) => ref.read(itemEditSelectionProvider.notifier).onToggleRequiresAckInput(state);
  void onAddPredicate(AlertPredicate predicate) => ref.read(itemEditSelectionProvider.notifier).onAddPredicate(predicate);
  void onUpdatePredicate(AlertPredicate oldP, AlertPredicate p) => ref.read(itemEditSelectionProvider.notifier).onUpdatePredicate(oldP, p);
  void onRemovePredicate(AlertPredicate predicate) => ref.read(itemEditSelectionProvider.notifier).onRemovePredicate(predicate);


  // Callbacks that display a dialog and change the state
  void onEditMembers()       { ref.read(itemEditSelectionProvider.notifier).set(editingAlertMembers: true); _displayMembersSelectionInput();}
  void onRequestedDelete()   { ref.read(itemEditSelectionProvider.notifier).onRequestDeletion(); displayDeleteConfirmDialog(context, ref); }

  void onContentEdit(String text) {
    final notifier = ref.read(itemEditSelectionProvider.notifier);

    if (notifier.alertRule.name == text) { return; }

    var alertRule = notifier.alertRule;
    var modified = alertRule.copyWith(name: text);
    notifier.changeItem(modified);
  }

  void onChangedMembers(int id, bool _) {
    final notifier = ref.watch(itemEditSelectionProvider.notifier);

    var item = widget.topology.items[id];
    AlertRulesService.logger.d("Changed members of alert, id=$id, members=$item");

    var alertRule = notifier.alertRule.copyWith(targetId: id);

    ref.read(itemEditSelectionProvider.notifier).changeItem(alertRule);
  }

  void _displayMembersSelectionInput() {
    var itemEditSelection = ref.watch(itemEditSelectionProvider);
    final notifier = ref.watch(itemEditSelectionProvider.notifier);
    if (!itemEditSelection.editingAlertMembers) { return; }

    var devices = widget.topology.devices;
    var groups = widget.topology.groups;

    Set<GroupableItem> options = {...devices, ...groups};

    isSelectedFn(option) => notifier.alertRule.targetId == option.id;
    onClose() => notifier.set(editingAlertMembers: false);
    onChanged(option, state) {
      onChangedMembers(option.id, state ?? false);
      ref.watch(dialogRebuildProvider.notifier).markDirty();
    }

    GroupableItemSelectionDialog(
      options: options,
      selectorType: ListSelectorType.radio,
      onChanged: onChanged,
      onClose: onClose,
      isSelectedFn: isSelectedFn,
      isAvailable: (_) => true

    ).show(context);
  }

  Widget _makeDeleteSection() {
    return DeleteSection(onDelete: onRequestedDelete, onRestore: onConfirmRestore);
  }

  DropdownButton _makeSourceDropdown(AlertSource initial) {
    return DropdownButton<String>(
      value: initial != AlertSource.unknown ? initial.name : null,
        hint: const Text("Fuente de datos"),
        items: AlertSource.values
          .where((value) => value != AlertSource.unknown)
          .map((type) => DropdownMenuItem(value: type.name, child: Text(type.name)))
          .toList(),
        onChanged: (val) {
          if (val == "unknown") { return; }
          final source = AlertSource.fromString(val ?? "");
          final notifier = ref.read(itemEditSelectionProvider.notifier);
          final AlertRule item = notifier.alertRule;
          notifier.changeItem(item.copyWith(source: source));
        },
        isExpanded: true,
      );
    }

    DropdownButton _makeRuleTypeDropdown(AlertRuleType initial) {
    return DropdownButton<String>(
      value: initial != AlertRuleType.unknown ? initial.name : null,
        hint: const Text("Tipo de regla"),
        items: AlertRuleType.values
          .where((value) => value != AlertRuleType.unknown)
          .map((type) => DropdownMenuItem(value: type.name, child: Text(type.name)))
          .toList(),
        onChanged: (val) {
          if (val == "unknown") { return; }
          final ruleType = AlertRuleType.fromString(val ?? "");
          final notifier = ref.read(itemEditSelectionProvider.notifier);
          final AlertRule item = notifier.alertRule;
          notifier.changeItem(item.copyWith(ruleType: ruleType));
        },
        isExpanded: true,
      );
    }

  DropdownButton _makeReduceLogicDropdown(AlertReduceLogic initial) {
    return DropdownButton<String>(
    value: initial != AlertReduceLogic.unknown ? initial.name : null,
      hint: const Text("Operación lógica"),
      items: AlertReduceLogic.values
          .where((value) => value != AlertReduceLogic.unknown)
          .map((type) => DropdownMenuItem(value: type.name, child: Text(type.name))).toList(),
      onChanged: (val) {
        if (val == "unknown") { return; }
        final op = AlertReduceLogic.fromString(val ?? "");
        final notifier = ref.read(itemEditSelectionProvider.notifier);
        final AlertRule item = notifier.alertRule;
        notifier.changeItem(item.copyWith(reduceLogic: op));
      },
      isExpanded: true,
    );
  }

  DropdownButton _makeSeverityDropdown(AlertSeverity initial) {
    return  DropdownButton<String>(
      value: initial != AlertSeverity.unknown ? initial.name : null,
        hint: const Text("Severidad de la alerta"),
        items: AlertSeverity.values
            .where((value) => value != AlertSeverity.unknown)
            .map((type) => DropdownMenuItem(value: type.name, child: Text(type.name))).toList(),
        onChanged: (val) {
          if (val == "unknown") { return; }
          final severity = AlertSeverity.fromString(val ?? "");
          final notifier = ref.read(itemEditSelectionProvider.notifier);
          final AlertRule item = notifier.alertRule;
          notifier.changeItem(item.copyWith(severity: severity));
        },
        isExpanded: true,
      );
    }

  SettingsTile _makeSourceInput(AlertRule rule) {
    var child = _makeSourceDropdown(rule.source);

    return SettingsTile(
      title: const Text("Fuente de datos"),
      leading: AlertEditView.sourceIcons[rule.source],
      trailing: makeTrailing(child, (){}, showEditIcon: false),
    );
  }

  SettingsTile _makeRuleTypeInput(AlertRule rule) {
    var child = _makeRuleTypeDropdown(rule.ruleType);

    var sustainedTimerSeconds = int.tryParse(_sustainedSecondsInputController.text);
    var sustainedTimerSecondsValid = sustainedTimerSeconds == null || sustainedTimerSeconds < 1;

    var secondsInput = SizedBox(
      width: 150,
      height: 60,
      child: Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: TextField(
            controller: _sustainedSecondsInputController,
            keyboardType: TextInputType.numberWithOptions(signed: false, decimal: false),
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r"[0-9]"))
            ],
            decoration: InputDecoration(
              counterText: "",
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              labelText: "Segundos",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8.0)),
              ),
              errorText: sustainedTimerSecondsValid ? "debe ser > 1" : null,
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.zero),
                borderSide: BorderSide(color: Colors.red)
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (text) => setState(() {onEditSustainedTimer(int.tryParse(text) ?? 1); })
        
          ),
      ),
    );

    return SettingsTile(
      title: const Text("Tipo de regla"),
      leading: AlertEditView.ruleTypeIcons[rule.ruleType],
      trailing: Row(
        children: [
          if (rule.ruleType == AlertRuleType.sustained)
            secondsInput,
          makeTrailing(child, (){}, showEditIcon: false),
        ],
      ),
    );
  }

  SettingsTile _makeReduceLogicInput(AlertRule rule) {
    var child = _makeReduceLogicDropdown(rule.reduceLogic);

    return SettingsTile(
      title: const Text("Lógica de predicado"),
      leading: AlertEditView.reduceLogicIcons[rule.reduceLogic],
      trailing: makeTrailing(child, (){}, showEditIcon: false),
    );
  }

  SettingsTile _makeSeverityInput(AlertRule rule) {
    var child = _makeSeverityDropdown(rule.severity);

    return SettingsTile(
      title: const Text("Severidad"),
      leading: AlertEditView.severityIcons[rule.severity],
      trailing: makeTrailing(child, (){}, showEditIcon: false),
    );
  }

  AbstractSettingsTile _makeNameInput(AlertRule rule, bool enabled, AlertRuleSet ruleSet) {

    bool modified = rule.isModifiedName(ruleSet);
    Color backgroundColor = modified ? addedItemColor : Colors.transparent;

    var editInput = EditTextField(
      initialText: rule.name,
      enabled: enabled,
      backgroundColor: backgroundColor,
      controller: _nameInputController,
      showEditIcon: true,
      onEditToggle: onEditName,
      onContentEdit: onContentEdit,
    );

    return SettingsTile(
      title: Text("Nombre"), leading: AlertEditView.nameIcon, trailing: editInput, onPressed: null
    );
  }

  AbstractSettingsTile _makeRequiresAckInput() {
    final state = ref.watch(itemEditSelectionProvider.notifier).alertRule.requiresAck;
    return SettingsTile(title: Text("Requiere Ack"), 
      trailing: 
        Switch.adaptive(
          value: state,
          onChanged: onToggleRequiresAckInput,
          thumbIcon: WidgetStatePropertyAll(state ? Icon(Icons.check) : null)
        ),);
  }

  AbstractSettingsTile _makeMembersInput() {
    final notifier = ref.watch(itemEditSelectionProvider.notifier); 

    var target = widget.topology.items[notifier.alertRule.targetId];

    var members = Text(target?.name ?? "");

    return SettingsTile(
      title: Text("Miembros"),
      leading: AlertEditView.membersIcon,
      trailing: makeTrailing(members, () => onEditMembers()),
      onPressed: null
    );
  }

  List<AbstractSettingsTile> _makePredicateInput(AlertRule rule) {
    const consolasStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.black87,
      letterSpacing: 0.5,
    );

    final Color bgColor = const Color.fromRGBO(216, 216, 216, 1);

    return rule.definition.map((predicate) {
      return SettingsTile(
        title: Wrap(
          spacing: 4,
          runSpacing: 8,
          children: [
            BadgeButton(text: "${predicate.left}${predicate.leftModifier}"    , backgroundColor: bgColor, textStyle: consolasStyle,),
            BadgeButton(text: predicate.op?.toPrettyString() ?? ""                         , backgroundColor: bgColor, textStyle: consolasStyle,),
            BadgeButton(text: "${predicate.right}${predicate.rightModifier}"  , backgroundColor: bgColor, textStyle: consolasStyle,),
          ],
        ),
        trailing: IconButton(onPressed: () => onRemovePredicate(predicate), icon: Icon(Icons.delete)),
        onPressed: (_) => EmptyDialog(
            child: 
              AlertRuleEditPredicate(
                topology: widget.topology,
                onSave: (newP) => onUpdatePredicate(predicate, newP),
                target: widget.topology.items[rule.targetId],
                initialValue: predicate,
                parentRule: rule,
              )
            ).show(context),
      );
    }).toList();
  }

  AbstractSettingsTile _makeAddPredicateButton(AlertRule rule) {
    final notifier = ref.watch(itemEditSelectionProvider.notifier);

    var target = widget.topology.items[notifier.alertRule.targetId];

    return SettingsTile(title: Row(
      children: [
        Spacer(),
        IconButton(
          onPressed: () => EmptyDialog(
            child: 
              AlertRuleEditPredicate(
                topology: widget.topology,
                onSave: onAddPredicate,
                target: target,
                parentRule: rule,
                initialValue: null,
              )
            ).show(context),
          icon: Icon(Icons.add),
        ),
        Spacer(),
      ],
    ));
  }

  Widget _buildSettingsView() {
    final notifier = ref.read(itemEditSelectionProvider.notifier);
    final itemSelection = ref.read(itemEditSelectionProvider);

    AlertRule rule = notifier.alertRule;

    bool editingName = itemSelection.editingAlertName;

    final List<AbstractSettingsSection> sections = [
      SettingsSection(
        title: Text(notifier.alertRule.name),
        tiles: [
          _makeNameInput(rule, editingName, widget.ruleSet),
          _makeRequiresAckInput(),
          _makeReduceLogicInput(rule),
          _makeSourceInput(rule),
          _makeRuleTypeInput(rule),
          _makeSeverityInput(rule),
          _makeMembersInput(),
        ],
      ),
      SettingsSection(
        title: Text("Predicados"),
        tiles: [
          ..._makePredicateInput(rule),
          _makeAddPredicateButton(rule)
        ]
      )
    ];

    if (widget.showDeleteButton) {
      sections.add(CustomSettingsSection(child: _makeDeleteSection(),));
    }

    return Column(
      children: [
        Expanded( child: SettingsList( sections: sections)),
        // Save button and cancel button
        makeFooter(ref, widget.topology),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return _buildSettingsView();
  }
}