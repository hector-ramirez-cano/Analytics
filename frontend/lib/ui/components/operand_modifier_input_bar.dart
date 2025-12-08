import 'package:aegis/models/alerts/alert_operand_modifier.dart';
import 'package:flutter/material.dart';

class OperandModifierInputBar extends StatefulWidget {
  final OperandModifier root;
  final Function(OperandModifier) onChangeRoot;

  const OperandModifierInputBar({super.key, required this.root, required this.onChangeRoot});

  @override
  State<OperandModifierInputBar> createState() => _OperandModifierInputBarState();
}

class _OperandModifierInputBarState extends State<OperandModifierInputBar> {
  late final List<OperandModifier> _ordered;
  late final List<List<TextEditingController>> _textControllers;
  OperandModifier? _root;

  @override
  initState() {
    super.initState();

    _root = widget.root;
    _ordered = [];
    _textControllers = [];
  }

  void _handleOnOperationChange(String? v, int index) {
    if (v == null) return;
      _ordered[index] = OperandModifier.fromLabel(v);

      // If the ones following it become invalid, we need to prune them
      if (_ordered.length > index+1) {
        final next = _ordered[index+1];
        if (next.definition.params.isNotEmpty && !next.definition.params[0].contains(_ordered[index].definition.result)) {
          _ordered.removeRange(index+1, _ordered.length);
        }
      }

      setState(() {_root = collapse();});
  }

  void _handleOnAddModifier() {
    if (_ordered.lastOrNull is OperandModifierNone){ return; }

    _ordered.add(OperandModifierNone());
    setState(() {
      _root = collapse();
    });
  }

  Widget _makeModifierParamInput(String label, String initialValue, Set<OperandType> operandTypes, int idx, int paramIdx) {

    if (_textControllers[idx][paramIdx].text.isEmpty) {
      _textControllers[idx][paramIdx].text = initialValue;
    }
    bool isValid () => operandTypes.any((op) => (OperandModifier.validators[op] ?? (_) => false) (_textControllers[idx][paramIdx].text));

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _textControllers[idx][paramIdx],
        decoration: InputDecoration(
          labelText: label, //label,
          prefixIcon: null, //icon,
          errorText: isValid() ? null : "Introduce un valor válido",
          border: const OutlineInputBorder(),
        ),
        onChanged: (newValue) {
          if(isValid()) {
            dynamic value;

            // If numeric is supported by the function param, try to parse
            if (operandTypes.contains(OperandType.arithmeticInteger) || operandTypes.contains(OperandType.agnostic)) {
              value = int.tryParse(newValue);
            }
            if (operandTypes.contains(OperandType.arithmeticFloating) || operandTypes.contains(OperandType.agnostic) && value == null) {
              value =  double.tryParse(newValue);
            }

            if (value == null && operandTypes.contains(OperandType.string) || operandTypes.contains(OperandType.agnostic)) {
              value = newValue;
            }
            _ordered[idx] = _ordered[idx].setParam(value, paramIdx);
            _root = collapse();
          }
          setState((){});
        },
      ),
    );
  }

  /// Makes a single modifier selector. Includes a drop down button to select the operation, and conditionally the parameters
  Widget _makeModifierSelector(OperandModifier? previous, OperandModifier current, int operandIdx) {
    while (_textControllers.length <= operandIdx) {
      _textControllers.add([]);
    }

    final prevReturnType = previous?.definition.result ?? OperandType.agnostic;

    final items = [
      for (final t in OperandModifier.variants)
        // Display only those for whom their first input is either agnostic, or same type as function
        if (t.params.isNotEmpty && (t.params[0].contains(prevReturnType) || t.params[0].contains(OperandType.agnostic) || previous == null))
          DropdownMenuItem(value: t.label, child: Text(t.label)),
    ];

    final opSelector = DropdownButton<String>(
      value: current.definition.label,
      isExpanded: true,
      hint: const Text("Operación"),
      items: items,
      onChanged: (v) => _handleOnOperationChange(v, operandIdx),
    );

    // Create controllers for the input, so the items can hold state across rebuilds
    while(_textControllers[operandIdx].length <= current.definition.params.length) {
      _textControllers[operandIdx].add(TextEditingController());
    }

    final List<Widget> inputs = [
      for (var (paramIdx, paramTypes) in current.definition.params.indexed.skip(1))
        _makeModifierParamInput(current.definition.paramLabels[paramIdx], current.getValue(paramIdx), paramTypes, operandIdx, paramIdx)
    ];

    return SizedBox(
      width: 128,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          opSelector,
          ...inputs,
        ],
      ),
    );
  }

  OperandModifier collapse() {
    if (_ordered.isEmpty) {
      widget.onChangeRoot(OperandModifierNone());
      return OperandModifierNone();
    }
    if (_ordered.length == 1) {
      widget.onChangeRoot(_ordered.first);
      return _ordered.first;
    }

    final newRoot = OperandModifierMulti(operations: List.from(_ordered));

    // final newRoot = OperandModifierMulti(operations: _ordered.map((op) => op.collapse()).where((op) => op is! OperandModifierNone).toList());

    widget.onChangeRoot(newRoot);

    return newRoot;
  }

  @override
  Widget build(BuildContext context) {

    _ordered.clear();
    final List<Widget> modifiers = [];
    final List<OperandModifier> modifierStack = [_root ?? OperandModifierNone()];
    OperandModifier? previousModifier;


    while (modifierStack.isNotEmpty) {
      final inner = modifierStack.removeLast();
      if (inner is OperandModifierMulti) {
        modifierStack.addAll(inner.operations.reversed); // added in reverse order, it's a stack
        continue;
      }

      final w = _makeModifierSelector(previousModifier, inner, _ordered.length);
      modifiers.add(w);
      _ordered.add(inner);
      previousModifier = inner;
    }


    return Wrap(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          child: const Text("Modificadores = "),
        ),
        ...modifiers,

        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: IconButton(icon: Icon(Icons.add), onPressed: _handleOnAddModifier,),
        )
      ]);
  }
}