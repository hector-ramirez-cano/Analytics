import 'package:aegis/services/metrics/metadata_service.dart';
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

class AlertRuleEditPredicate extends StatefulWidget {
  const AlertRuleEditPredicate({
    super.key,
    required this.topology,
    required this.target,
    required this.initialValue,
    required this.onSave,
  });

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
  AlertPredicate _predicate = AlertPredicate.empty();
  late final TextEditingController _rightController;

  @override
  void initState() {
    super.initState();
    _leftController  = TextEditingController();
    _rightController = TextEditingController();

    if (widget.initialValue != null) {
      _predicate = widget.initialValue!;

      if (_predicate.left.isConst) {
        _leftController.text = _predicate.left.value.toString();
      }

      if (_predicate.right.isConst) {
        _rightController.text = _predicate.right.value.toString();
      }
    }
  }

  void _handleConstLeftToggle (bool value)  => setState(() { _predicate = _predicate.setLeftConst(value);   });

  void _handleConstRightToggle(bool value)  => setState(() { _predicate = _predicate.setRightConst (value); });

  void _handleForcedLeftToggle (bool value) => setState(() { _predicate = _predicate.setLeftForced (value); });

  void _handleForcedRightToggle(bool value) => setState(() { _predicate = _predicate.setRightForced(value); });

  void _handleOpToggle(AlertPredicateOperation op) => setState(() { _predicate = _predicate.setOperation(op); });

  void _handleTypeChange(String? typeAsString, bool isLeft) {
    if (typeAsString == "unknown") { return; }
    final type = FactsDataType.fromString(typeAsString ?? "");

    if (type == null) { return; }

    if (type == FactsDataType.nullable) {
      _predicate = _predicate.setValue(null, isLeft);
    }

    if (type == FactsDataType.number || type == FactsDataType.string) {
      String input = isLeft ? _leftController.text : _rightController.text;
      _predicate = _predicate.setValue(input, isLeft);
    }

    setState(() { _predicate = _predicate.setConstType(type); });

    // if changing the type causes the op to be disabled, set op to null
    if (_predicate.op != null && !_isOpEnabled(_predicate.op!)) {
      setState(() {
        _predicate = _predicate.forcedCopy(left: _predicate.left, right: _predicate.right, op: null);
      });
    }
  }

  /// Returns whether a given operation is valid for the types
  /// Currently only checks if the operation is valid only if the predicate is const
  bool _isOpEnabled(AlertPredicateOperation op) {
    // TODO: Check if is valid if non-const is valid
      return !_predicate.hasConst()
      || (
        _predicate.constValue != null
        && op.isValidFor(_predicate.constValue!.dataType)
      );
  }

  void _handleDirectInputChanged(bool isLeft, String text, bool Function(dynamic) validator) {
    setState(() {
      if (validator(text)) {
        _predicate = _predicate.setValue(text, isLeft);
      }
    });
  }

  void _handleVariableInputSelect(bool isLeft, String val) {
    setState(() {
      _predicate = _predicate.setValue(val, isLeft);
    });
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

  Widget _makeVariableSubtitle(dynamic item) {
    
    return Consumer(builder:(context, ref, child) {

      final values = widget.topology.getAllAvailableValues(widget.target);

      final metadata = ref.watch(metadataServiceProvider(metadata: values, deviceId: widget.target.id));
        return metadata.when(
          data: (metadata) {
            if (metadata.isEmpty) { return Text("Sin datos"); }
            return Text(metadata[0][item]?.toString().truncate(50) ?? "Sin datos");
          },
          error: (e, st) => Text("Sin datos"),
          loading: () => Text("Cargando...")
        );
    },);
    
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
        isSelectedFn: (val) => isLeft ? val == _predicate.left.value : val == _predicate.right.value,
        onChanged: (val, _) => _handleVariableInputSelect(isLeft, val),
        subtitleBuilder: (val) => _makeVariableSubtitle(val),
      );
    }

    final onToggle = isLeft ? _handleConstLeftToggle : _handleConstRightToggle;
    final onToggleForced = isLeft ? _handleForcedLeftToggle : _handleForcedRightToggle;
    final enabled = isLeft ? !_predicate.right.isConst : !_predicate.left.isConst;

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

  Widget _makeTypeDropdown(AlertRuleOperand operand, bool isLeft) {
    return SizedBox(
      height: 40,
      width: MediaQuery.of(context).size.width * 0.30,
      child: DropdownButton<String>(
        value: operand.isInit ? operand.dataType.name : null,
          hint: const Text("Tipo de dato"),
          items: FactsDataType.values
              .map((type) => DropdownMenuItem(value: type.name, child: Text(type.name)))
              .toList(),
          onChanged: (val) => _handleTypeChange(val, isLeft),
          isExpanded: true,
        ),
    );
  }

  Widget _makeBooleanToggle(bool isLeft, bool? initial) {
    _predicate = _predicate.setValue(initial ?? false, isLeft);

    return _makeToggle("Valor", initial ?? false, true, (state) => setState(() {
      _predicate = _predicate.setValue(state, isLeft);
    }), leftPadding: MediaQuery.of(context).size.width * 0.125);
  }

  Widget _makeConstantSelector(bool isLeft) {
    AlertRuleOperand? constOperand = _predicate.constValue;

    if (constOperand == null) { throw Exception("Const selector shown for non constant value!"); }

    dynamic constValue = constOperand.value;

    Widget child;
    switch (constOperand.dataType) {
      case FactsDataType.boolean:
        constValue = constValue is bool ? constValue : null;
        child = Padding(
          padding: const EdgeInsets.all(28.0),
          child: _makeBooleanToggle(isLeft, constValue),
        );

      case FactsDataType.nullable:
        constValue = null;
        child = Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [ Spacer(), Text("NULL"), Spacer(), ],
          ),
        );

      case FactsDataType.number:
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

      case FactsDataType.string:
        child = _makeDirectInput(isLeft, "Constante", Icon(Icons.sync_disabled));
    }

    final onToggle = isLeft ? _handleConstLeftToggle : _handleConstRightToggle;
    final enabled = isLeft ? !_predicate.right.isConst  : !_predicate.left.isConst;

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.42,
      child: Column(
        key: Key("Column_$onToggle"),
        children: [
          _makeToggle("Constante", true, enabled, onToggle),
          _makeTypeDropdown(constOperand, isLeft,),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.35,
            height: MediaQuery.of(context).size.height * 0.65,
            child: child,
          )
        ],
      ),
    );

  }

  Widget _makeSide(AlertRuleOperand operand, bool isLeft,bool forced) {
    if (operand.isConst) {
      return _makeConstantSelector(isLeft);
    } else {
      return _makeVariableSelector(forced, isLeft);
    }
  }

  Widget _makeOpSelector() {
    TextStyle style = TextStyle(fontSize: 18);
    TextStyle selectedStyle = TextStyle(fontSize: 18, color: Colors.white);

    selected(AlertPredicateOperation op) => op == _predicate.op;

    final ops = AlertPredicateOperation.values
      .map((op) =>
        BadgeButton(
          text: op.toPrettyString(),
          textStyle: selected(op) ? selectedStyle : style,
          backgroundColor: selected(op) ? Color.fromRGBO(41, 99, 138, 1) : Colors.white,
          onPressed: _isOpEnabled(op) ? () => _handleOpToggle(op) : null,
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

    onClose () {
      if(context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
    final onSave = !_predicate.isValid ? null : () {
      widget.onSave(_predicate);
      onClose();
    };


    return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: 4,
          children: [
            Text("Predicado = "),
            BadgeButton(text: _predicate.left.toString(), backgroundColor: bgColor, textStyle: consolasStyle,),
            BadgeButton(text: _predicate.op?.toPrettyString() ?? "", backgroundColor: bgColor, textStyle: consolasStyle,),
            BadgeButton(text: _predicate.right.toString() , backgroundColor: bgColor, textStyle: consolasStyle,),
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
          _makeSide(_predicate.left, true, _predicate.left.isForced),
          _makeOpSelector(),
          _makeSide(_predicate.right, false, _predicate.right.isForced),
        ],),
        _makeFooter()
      ],
    );
  }
}