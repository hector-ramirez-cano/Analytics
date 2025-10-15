import 'package:flutter/material.dart';
import 'package:network_analytics/models/alerts/alert_predicate_operation.dart';
import 'package:network_analytics/models/analytics_item.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/ui/components/badge_button.dart';
import 'package:network_analytics/ui/components/list_selector.dart';

class AlertRuleDefinitionInput extends StatefulWidget {
  final Topology topology;
  final GroupableItem target;
  
  const AlertRuleDefinitionInput({
    super.key,
    required this.topology,
    required this.target,
  });

  static bool defaultValidator(dynamic _) => true;

  @override
  State<AlertRuleDefinitionInput> createState() => _AlertRuleDefinitionInputState();
}

enum AlertConstTypes {
  string,
  number,
  boolean,
  nullable;

  static AlertConstTypes? fromString(String value) {
    switch (value) {
      case "string":
        return string;
      case "number":
        return number;
      case "boolean":
        return boolean;
      case "nullable":
        return nullable;
    }
    return null;
  }
}

class _AlertRuleDefinitionInputState extends State<AlertRuleDefinitionInput> {
  bool _leftConst = false;
  bool _rightConst = false;
  bool _leftForced = false;
  bool _rightForced = false;
  AlertPredicateOperation? _selectedOperation;
  AlertConstTypes? _constType;
  dynamic _constValue;
  late final TextEditingController _leftController;
  late final TextEditingController _rightController;
  String? _leftValue;
  String? _rightValue;

  @override
  void initState() {
    super.initState();
    _leftController = TextEditingController();
    _rightController = TextEditingController();
  }

  void _handleConstLeftToggle (bool value)  => setState(() { if (value) { _rightConst = false; } _leftConst  = value; });
  void _handleConstRightToggle(bool value)  => setState(() { if (value) { _leftConst  = false; } _rightConst = value; });
  void _handleForcedLeftToggle (bool value) => setState(() { _leftForced  = value; });
  void _handleForcedRightToggle(bool value) => setState(() { _rightForced = value; });
  void _handleOpToggle(AlertPredicateOperation op) => setState(() { _selectedOperation = _selectedOperation == op ? null : op; });

  Widget _makeToggle(String label, bool value, bool enabled, Function(bool) onToggle, {double leftPadding = 64.0}) {
    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: Row(
        children: [
          Switch.adaptive(
            key: Key("${label}_$onToggle"),
            value: value,
            onChanged: enabled ? onToggle : null,
            thumbIcon: WidgetStatePropertyAll(value ? Icon(Icons.check) : null)
          ),
          Text(label),
          Spacer(),
        ],
      ),
    );
  }

  Widget _makeDirectInput(bool left, String label, Icon prefixIcon, {TextInputType? inputType, bool Function(dynamic) validator = AlertRuleDefinitionInput.defaultValidator}) {
    Key formKey = ValueKey('${left ? "left" : "right"}_$label');
    final controller = left ? _leftController : _rightController;
    final hasError = !validator(controller.text);
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: TextField(
        key: formKey,
        controller: controller,
        keyboardType: inputType,
        decoration: InputDecoration(
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          labelText: label,
          prefixIcon: prefixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.zero),
            borderSide: BorderSide(color: Colors.red)
          ),
          errorText: hasError ? "Introduce un número válido" : null,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onChanged: (text) {
          setState(() {
            if (validator(controller.text)) {
              _constValue = text;
            }
          });
        },
        
      ),
    );
  }

  Widget _makeVariableSelector(bool forced, bool isLeft) {
    Widget child;
    if (forced) { 
      child = _makeDirectInput(isLeft, "Variable", Icon(Icons.import_contacts_outlined));
    }
    else {
      child = ListSelector<String>(
        options: widget.topology.getAllAvailableValues(widget.target),
        selectorType: ListSelectorType.radio,
        toText: (v) => v,
        onClose: null,
        isAvailable: (_) => true,
        isSelectedFn: (val) => isLeft ? val == _leftValue : val == _rightValue,
        onChanged: (val, _) => {
          setState(() {
            if (isLeft) { _leftValue = val; }
            else { _rightValue = val; }
          })
          
        },
      );
    }

    final onToggle = isLeft ? _handleConstLeftToggle : _handleConstRightToggle;
    final onToggleForced = isLeft ? _handleForcedLeftToggle : _handleForcedRightToggle;
    final enabled = isLeft ? !_rightConst : !_leftConst;
    
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.42,
      child: Column(
        key: Key("Column_$onToggle"),
        children: [
          _makeToggle("Constante", false, enabled, onToggle),
          _makeToggle("Introducir manualmente la variable", forced, true, onToggleForced),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.35,
            height: MediaQuery.of(context).size.height * 0.7,
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _makeTypeDropdown(AlertConstTypes? initial) {
    return SizedBox(
      height: 40,
      width: MediaQuery.of(context).size.width * 0.30,
      child: DropdownButton<String>(
        value: initial?.name,
          hint: const Text("Tipo de dato"),
          items: AlertConstTypes.values
              .map((type) => DropdownMenuItem(value: type.name, child: Text(type.name)))
              .toList(),
          onChanged: (val) {
            if (val == "unknown") { return; }
            final type = AlertConstTypes.fromString(val ?? "");
            setState(() { _constType = type; });
          },
          isExpanded: true,
        ),
    );
  }

  Widget _makeBooleanToggle(bool? initial) {
    return _makeToggle("Valor", initial ?? false, true, (state) => setState(() {
      _constValue = state;
    }), leftPadding: MediaQuery.of(context).size.width * 0.125);
  }
  
  Widget _makeConstantSelector(bool isLeft) {

    Widget child;
    switch (_constType) {
      case AlertConstTypes.boolean:
        _constValue = _constValue is bool ? _constValue as bool : null;
        child = Padding(
          padding: const EdgeInsets.all(28.0),
          child: _makeBooleanToggle(_constValue),
        );

      case AlertConstTypes.nullable:
        _constValue = null;
        child = Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [ Spacer(), Text("NULL"), Spacer(), ],
          ),
        );

      case AlertConstTypes.number:
        bool validator(value) {
          return value is String && (value.isEmpty || double.tryParse(value) != null);
        }
        child = _makeDirectInput(
          isLeft,
          "Constante",
          Icon(Icons.sync_disabled),
          inputType: TextInputType.numberWithOptions(signed: true, decimal: true),
          validator: validator,
        );

      case AlertConstTypes.string:
      case null:
        child = _makeDirectInput(isLeft, "Constante", Icon(Icons.sync_disabled));
    }
    
    final onToggle = isLeft ? _handleConstLeftToggle : _handleConstRightToggle;
    final enabled = isLeft ? !_rightConst  : !_leftConst;
    
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.42,
      child: Column(
        key: Key("Column_$onToggle"),
        children: [
          _makeToggle("Constante", true, enabled, onToggle),
          _makeTypeDropdown(_constType),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.35,
            height: MediaQuery.of(context).size.height * 0.7,
            child: child,
          )
          
        ],
      ),
    );
    
  }

  Widget _makeSide(bool constant, bool forced, bool isLeft) {
    if (constant) {
      return _makeConstantSelector(isLeft);
    } else {
      return _makeVariableSelector(forced, isLeft);
    }
  }

  Widget _makeOpSelector() {
    TextStyle style = TextStyle(fontSize: 18);
    TextStyle selectedStyle = TextStyle(fontSize: 18, color: Colors.white);

    selected(op) => op == _selectedOperation;

    final ops = AlertPredicateOperation.values
      .map((op) => 
        BadgeButton(
          text: op.toPrettyString(),
          textStyle: selected(op) ? selectedStyle : style,
          backgroundColor: selected(op) ? Color.fromRGBO(41, 99, 138, 1) : Colors.white,
          onPressed: () => _handleOpToggle(op),
        )).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 128),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8,
        children: ops,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      _makeSide(_leftConst, _leftForced, true),
      _makeOpSelector(),
      _makeSide(_rightConst, _rightForced, false),
    ],);
  }
}