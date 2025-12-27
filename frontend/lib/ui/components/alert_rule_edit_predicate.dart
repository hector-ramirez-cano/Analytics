import 'package:aegis/models/alerts/alert_operand.dart';
import 'package:aegis/models/alerts/alert_operand_modifier.dart';
import 'package:aegis/models/alerts/alert_rule.dart';
import 'package:aegis/models/alerts/alert_source.dart';
import 'package:aegis/services/metrics/metadata_service.dart';
import 'package:aegis/theme/app_colors.dart';
import 'package:aegis/ui/components/operand_modifier_input_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aegis/extensions/string_extensions.dart';
import 'package:aegis/models/alerts/alert_predicate.dart';
import 'package:aegis/models/alerts/alert_predicate_operation.dart';
import 'package:aegis/models/analytics_item.dart';
import 'package:aegis/models/enums/facts_const_types.dart';
import 'package:aegis/models/topology.dart';
import 'package:aegis/ui/components/badge_button.dart';
import 'package:aegis/ui/components/list_selector.dart';

const badgeButtonTextStyle = TextStyle(
  fontFamily: 'monospace',
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: AppColors.alertRuleEditBadgeFontColor,
  letterSpacing: 0.5,
);

final Color badgeButtonBgColor = const Color.fromRGBO(216, 216, 216, 1);

class AlertRuleEditPredicate extends StatefulWidget {
  const AlertRuleEditPredicate({
    super.key,
    required this.topology,
    required this.target,
    required this.parentRule,
    required this.initialValue,
    required this.onSave,
  });

  final AlertRule parentRule;
  final AlertPredicate? initialValue;
  final Function(AlertPredicate op) onSave;
  final GroupableItem target;
  final Topology topology;

  @override
  State<AlertRuleEditPredicate> createState() => _AlertRuleEditPredicateState();

  static bool defaultValidator(dynamic _) => true;
}

class _AlertRuleEditPredicateState extends State<AlertRuleEditPredicate> {
  late final TextEditingController _leftController;
  late final TextEditingController _rightController;
  AlertPredicate _predicate = AlertPredicate.empty();

  @override
  void initState() {
    super.initState();
    _leftController = TextEditingController();
    _rightController = TextEditingController();

    if (widget.initialValue != null) {
      _predicate = widget.initialValue!;
      if (_predicate.left.isConst) _leftController.text = _predicate.left.value.toString();
      if (_predicate.right.isConst) _rightController.text = _predicate.right.value.toString();
    }
  }


  void _handleConstLeftToggle(bool v) => setState(() {
    _predicate = _predicate.setLeftConst(v);
  });

  void _handleConstRightToggle(bool v) => setState(() {
    _predicate = _predicate.setRightConst(v);
  });

  void _handleForcedLeftToggle(bool v) => setState(() {
    _predicate = _predicate.setLeftForced(v);
  });

  void _handleForcedRightToggle(bool v) => setState(() {
    _predicate = _predicate.setRightForced(v);
  });

  void _handleOpToggle(AlertPredicateOperation op) => setState(() {
    _predicate = _predicate.setOperation(op);
  });

  void _handleSetLeftModifier(OperandModifier left) => setState(() {
    _predicate = _predicate.copyWith(leftModifier: left);
  });

  void _handleSetRightModifier(OperandModifier right) => setState(() {
    _predicate = _predicate.copyWith(rightModifier: right);
  });

  void _handleTypeChange(String? val, bool isLeft) {
    if (val == null || val == "unknown") return;
    final type = FactsDataType.fromString(val);
    if (type == null) return;

    if (type == FactsDataType.nullable) {
      _predicate = _predicate.setValue(null, isLeft);
    }

    if (type == FactsDataType.number || type == FactsDataType.string) {
      final text = isLeft ? _leftController.text : _rightController.text;
      _predicate = _predicate.setValue(text, isLeft);
    }

    setState(() => _predicate = _predicate.setConstType(type));

    if (_predicate.op != null && !_isOpEnabled(_predicate.op!)) {
      setState(() => _predicate = _predicate.forcedCopy(
            left: _predicate.left,
            right: _predicate.right,
            op: null,
            leftModifier: _predicate.leftModifier,
            rightModifier: _predicate.rightModifier,
          ));
    }
  }

  bool _isOpEnabled(AlertPredicateOperation op) {
    return !_predicate.hasConst() || (_predicate.constValue != null && op.isValidFor(_predicate.constValue!.dataType));
  }

  void _handleDirectInputChanged(bool isLeft, String text, bool Function(dynamic) validator) {
    if (!validator(text)) return;
    setState(() => _predicate = _predicate.setValue(text, isLeft));
  }

  void _handleVariableInputSelect(bool isLeft, String value) {
    setState(() => _predicate = _predicate.setValue(value, isLeft));
  }

  Widget _makeToggle(String label, bool value, bool enabled, Function(bool) onToggle, {double leftPadding = 32}) {
    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: Row(children: [
        Switch.adaptive(value: value, onChanged: enabled ? onToggle : null),
        Text(label),
        const Spacer(),
      ]),
    );
  }

  Widget _makeDirectInput(bool isLeft, String label, Icon icon,
    {TextInputType? inputType, bool Function(dynamic) validator = AlertRuleEditPredicate.defaultValidator}
  ) {
    final controller = isLeft ? _leftController : _rightController;
    final hasError = !validator(controller.text);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        onChanged: (t) => _handleDirectInputChanged(isLeft, t, validator),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon,
          errorText: hasError ? "Introduce un número válido" : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _makeVariableSelector(bool forced, bool isLeft) {
    final Set<String> variableNames;
    switch (widget.parentRule.source) {
      
      case AlertSource.syslog:
        variableNames = {"syslog_message"};
        
      case AlertSource.facts:
        variableNames = widget.topology.getAllAvailableValues(widget.target);

      case AlertSource.unknown:
        variableNames = {};
    }

    final forcedToggle = isLeft ? _handleForcedLeftToggle : _handleForcedRightToggle;
    final constToggle = isLeft ? _handleConstLeftToggle : _handleConstRightToggle;
    final enabled = isLeft ? !_predicate.right.isConst : !_predicate.left.isConst;

    Widget child = forced
        ? _makeDirectInput(isLeft, "Variable", const Icon(Icons.import_contacts_outlined))
        : ListSelector<String>(
            onClose: null,
            onClear: () => {},
            shrinkWrap: true,
            options: variableNames,
            selectorType: ListSelectorType.radio,
            toText: (v) => v,
            onChanged: (val, _) => _handleVariableInputSelect(isLeft, val),
            isAvailable: (_) => true,
            isSelectedFn: (v) => (isLeft ? _predicate.left.value : _predicate.right.value) == v,
            subtitleBuilder: (v) => _makeVariableSubtitle(v),
          );

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.40,
      child: Column(children: [
        _makeToggle("Constante", false, enabled, constToggle),
        _makeToggle("Introducir manualmente", forced, true, forcedToggle),
        Expanded(child: child),
      ]),
    );
  }

  Widget _makeVariableSubtitle(String item) {
    if (item == "syslog_message") {
      return Text("");
    }

    return Consumer(builder: (context, ref, child) {
      final values = widget.topology.getAllAvailableValues(widget.target);
      final md = ref.watch(metadataServiceProvider(metadata: values, deviceId: widget.target.id));
      return md.when(
        loading: () => const Text("Cargando…"),
        error: (_, _) => const Text("Sin datos"),
        data: (m) => Text(m.isEmpty ? "Sin datos" : (m[0][item]?.toString().truncate(50) ?? "Sin datos")),
      );
    });
  }

  Widget _makeConstantSelector(bool isLeft) {
    final constOp = _predicate.constValue!;
    Widget child;

    switch (constOp.dataType) {
      case FactsDataType.boolean:
        final v = constOp.value is bool ? constOp.value : false;
        child = _makeToggle("Valor", v, true, (s) => setState(() => _predicate = _predicate.setValue(s, isLeft)));
        break;

      case FactsDataType.nullable:
        child = const Center(child: Text("NULL"));
        break;

      case FactsDataType.number:
        child = _makeDirectInput(
          isLeft,
          "Constante",
          const Icon(Icons.sync_disabled),
          inputType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          validator: (v) => v is String && (v.isEmpty || double.tryParse(v) != null),
        );
        break;

      case FactsDataType.string:
        child = _makeDirectInput(isLeft, "Constante", const Icon(Icons.sync_disabled));
        break;
    }

    final toggle = isLeft ? _handleConstLeftToggle : _handleConstRightToggle;
    final enabled = isLeft ? !_predicate.right.isConst : !_predicate.left.isConst;

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.40,
      child: Column(children: [
        _makeToggle("Constante", true, enabled, toggle),
        _makeTypeDropdown(constOp, isLeft),
        Expanded(child: child),
      ]),
    );
  }

  Widget _makeTypeDropdown(AlertRuleOperand op, bool isLeft) {
    return SizedBox(
      height: 40,
      child: DropdownButton<String>(
        value: op.isInit ? op.dataType.name : null,
        isExpanded: true,
        hint: const Text("Tipo de dato"),
        items: [
          for (final t in FactsDataType.values)
            DropdownMenuItem(value: t.name, child: Text(t.name)),
        ],
        onChanged: (v) => _handleTypeChange(v, isLeft),
      ),
    );
  }

  Widget _makeOperandModifier(bool isLeft) {
    final modifier = (isLeft ? widget.initialValue?.leftModifier : widget.initialValue?.rightModifier) ?? OperandModifierNone();
    return OperandModifierInputBar(root: modifier, onChangeRoot: (root) => (isLeft ? _handleSetLeftModifier(root) : _handleSetRightModifier(root)),);
  }

  Widget _makeSide(AlertRuleOperand op, bool isLeft, bool forced) {
    final modifier = isLeft ? _predicate.leftModifier : _predicate.rightModifier;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: op.isConst
                ? _makeConstantSelector(isLeft)
                : _makeVariableSelector(forced, isLeft),
          ),
          const SizedBox.square(dimension: 8,),
          if (!op.isConst) 
            _makeOperandModifier(isLeft),

          BadgeButton(text: "$op$modifier", backgroundColor: badgeButtonBgColor, textStyle: badgeButtonTextStyle,),
        ],
      ),
    );
  }

  Widget _makeOpSelector() {
    TextStyle style = TextStyle(fontSize: 18);
    TextStyle selectedStyle = TextStyle(fontSize: 18, color: AppColors.alertRuleEditOpSelectorFontColor);
    selected(AlertPredicateOperation op) => op == _predicate.op;


    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 8,
      children: [
        for (final op in AlertPredicateOperation.values)
          BadgeButton(
            text: op.toPrettyString(),
            textStyle: selected(op) ? selectedStyle : style,
            backgroundColor: selected(op) ? AppColors.alertRuleEditOpSelectorSelectedBackgroundColor: AppColors.alertRuleEditOpSelectorBackgroundColor,
            onPressed: _isOpEnabled(op) ? () => _handleOpToggle(op) : null,
          ),
      ],
    );
  }

  Widget _makeFooter() {
    void onClose() {
      if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
    }

    final save = !_predicate.isValid
        ? null
        : () {
            widget.onSave(_predicate);
            onClose();
          };

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        spacing: 8,
        mainAxisAlignment: MainAxisAlignment.end, children: [
        BadgeButton(text: "${_predicate.left}${_predicate.leftModifier}", backgroundColor: badgeButtonBgColor, textStyle: badgeButtonTextStyle,),
        BadgeButton(text: _predicate.op?.toPrettyString() ?? "", backgroundColor: badgeButtonBgColor, textStyle: badgeButtonTextStyle,),
        BadgeButton(text: "${_predicate.right}${_predicate.rightModifier}", backgroundColor: badgeButtonBgColor, textStyle: badgeButtonTextStyle,),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: onClose, child: const Text("Descartar")),
        ElevatedButton(onPressed: save, child: const Text("Guardar")),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _makeSide(_predicate.left, true, _predicate.left.isForced),
              _makeOpSelector(),
              _makeSide(_predicate.right, false, _predicate.right.isForced),
            ],
          ),
        ),
        _makeFooter(),
      ]),
    );
  }
}
