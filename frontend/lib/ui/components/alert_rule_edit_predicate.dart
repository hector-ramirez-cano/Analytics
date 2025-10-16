import 'package:flutter/material.dart';
import 'package:network_analytics/models/alerts/alert_predicate.dart';
import 'package:network_analytics/models/alerts/alert_predicate_operation.dart';
import 'package:network_analytics/models/analytics_item.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/ui/components/badge_button.dart';
import 'package:network_analytics/ui/components/list_selector.dart';

class AlertRuleEditPredicate extends StatefulWidget {
  final Topology topology;
  final GroupableItem target;
  final Function(AlertPredicate op) onSave;
  
  const AlertRuleEditPredicate({
    super.key,
    required this.topology,
    required this.target,
    required this.onSave,
  });

  static bool defaultValidator(dynamic _) => true;

  @override
  State<AlertRuleEditPredicate> createState() => _AlertRuleEditPredicateState();
}

enum AlertConstTypes {
  string,
  number,
  boolean,
  nullable,;

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

class _AlertRuleEditPredicateState extends State<AlertRuleEditPredicate> {
  bool _leftConst = false;
  bool _rightConst = false;
  bool _leftForced = false;
  bool _rightForced = false;
  AlertPredicateOperation? _selectedOperation;
  AlertConstTypes? _constType;
  late final TextEditingController _leftController;
  late final TextEditingController _rightController;
  // TODO: Refactor initial values and const handling
  dynamic _leftValue = "\$";
  dynamic _rightValue = "\$";

  @override
  void initState() {
    super.initState();
    _leftController = TextEditingController();
    _rightController = TextEditingController();
  }

  void _handleConstLeftToggle (bool value)  => setState(() { if (value) { _rightConst = false; } _leftConst  = value; _leftValue = null;});
  void _handleConstRightToggle(bool value)  => setState(() { if (value) { _leftConst  = false; } _rightConst = value; _rightValue = null;});
  void _handleForcedLeftToggle (bool value) => setState(() { _leftForced  = value; _leftValue = null;});
  void _handleForcedRightToggle(bool value) => setState(() { _rightForced = value; _rightValue = null;});
  void _handleOpToggle(AlertPredicateOperation op) => setState(() { _selectedOperation = _selectedOperation == op ? null : op; });
  
  void _handleDirectInputChanged(bool isLeft, String text, bool Function(dynamic) validator) {
    setState(() {
      if (validator(text)) {
        if (isLeft) {
          _leftValue = cast(isLeft, text);
        } else {
          _rightValue = cast(isLeft, text);
        }
      }
    });
  }

  void _handleVariableInputSelect(bool isLeft, String val) {
    setState(() {
      if (isLeft) { _leftValue = "\$$val"; }
      else { _rightValue = "\$$val"; }
    });
  }

  dynamic cast(bool left, String text) {
    bool isConst = left ? _leftConst : _rightConst;
    AlertConstTypes? type = _constType;

    if (!isConst) { return "&$text"; }

    switch (type) {
      
      case AlertConstTypes.string:
        return text;

      case AlertConstTypes.number:
        return double.parse(text);

      case null:
        return null;

      // these types should never call to cast
      case AlertConstTypes.boolean:
      case AlertConstTypes.nullable:
        throw Exception("Unreachable code reached!");
    }
  }

  String _sideToString(dynamic side) {
    
    if (side is String) { 
      if (side.contains("\$")) {
        if (side.length == 1) { return ""; }
        return side;
      }
      return '"$side"'; 
    }
    return side.toString();
  }

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

  Widget _makeDirectInput(bool isLeft, String label, Icon prefixIcon, {TextInputType? inputType, bool Function(dynamic) validator = AlertRuleEditPredicate.defaultValidator}) {
    Key formKey = ValueKey('${isLeft ? "left" : "right"}_$label');
    final controller = isLeft ? _leftController : _rightController;
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
        onChanged: (text) => _handleDirectInputChanged(isLeft, text, validator)
        
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
        isSelectedFn: (val) => isLeft ? "\$$val" == _leftValue : "\$$val" == _rightValue,
        onChanged: (val, _) => _handleVariableInputSelect(isLeft, val)
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
            width : MediaQuery.of(context).size.width  * 0.35,
            height: MediaQuery.of(context).size.height * 0.65,
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _makeTypeDropdown(bool isLeft, AlertConstTypes? initial) {
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
            
            if (type == AlertConstTypes.nullable) { 
              if (isLeft) { _leftValue = null; }
              else { _rightValue = null; }
            }
            setState(() { _constType = type; });
          },
          isExpanded: true,
        ),
    );
  }

  Widget _makeBooleanToggle(bool isLeft, bool? initial) {
    if (isLeft) {_leftValue = initial ?? false; } else { _rightValue = initial ?? false; }

    return _makeToggle("Valor", initial ?? false, true, (state) => setState(() {
      if (isLeft) {_leftValue = state; } else { _rightValue = state; }
    }), leftPadding: MediaQuery.of(context).size.width * 0.125);
  }
  
  Widget _makeConstantSelector(bool isLeft) {
    dynamic constValue = isLeft ? _leftValue : _rightValue;

    Widget child;
    switch (_constType) {
      case AlertConstTypes.boolean:
        constValue = constValue is bool ? constValue : null;
        child = Padding(
          padding: const EdgeInsets.all(28.0),
          child: _makeBooleanToggle(isLeft, constValue),
        );

      case AlertConstTypes.nullable:
        constValue = null;
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
          _makeTypeDropdown(isLeft, _constType),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.35,
            height: MediaQuery.of(context).size.height * 0.65,
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

  Widget _makeFooter() {
    const consolasStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.black87,
      letterSpacing: 0.5,
    );

    final Color bgColor = const Color.fromRGBO(216, 216, 216, 1);
    final saveBtnStyle = ElevatedButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      disabledBackgroundColor: Theme.of(context).colorScheme.onSurface.withAlpha(50),
      disabledForegroundColor: Theme.of(context).colorScheme.onSurface.withAlpha(50),
    );
    final leftValid  = (_leftValue  != null && _leftValue  != "\$") || (_leftConst  && _constType == AlertConstTypes.nullable);
    final rightValid = (_rightValue != null && _rightValue != "\$") || (_rightConst && _constType == AlertConstTypes.nullable);
    final valid = leftValid && rightValid && _selectedOperation != null;

    onClose () {
      if(context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
    final onSave = !valid ? null : () {
      widget.onSave(AlertPredicate(left: _leftValue, right: _rightValue, op: _selectedOperation!));
      onClose();
    };


    return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: 4,
          children: [
            Text("Predicado = "),
            BadgeButton(text: _sideToString(_leftValue), backgroundColor: bgColor, textStyle: consolasStyle,),
            BadgeButton(text: _selectedOperation?.toPrettyString() ?? "", backgroundColor: bgColor, textStyle: consolasStyle,),
            BadgeButton(text: _sideToString(_rightValue) , backgroundColor: bgColor, textStyle: consolasStyle,),
            SizedBox(width: 16,),
            ElevatedButton(onPressed: onClose, child: Text("Descartar")),
            ElevatedButton(onPressed: onSave, style: saveBtnStyle, child: Text("Guardar"),),
          ],
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          _makeSide(_leftConst, _leftForced, true),
          _makeOpSelector(),
          _makeSide(_rightConst, _rightForced, false),
        ],),
        _makeFooter()
      ],
    );
  }
}