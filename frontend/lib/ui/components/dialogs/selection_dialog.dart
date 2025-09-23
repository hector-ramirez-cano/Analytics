import 'package:flutter/material.dart';
import 'package:network_analytics/ui/components/list_selector.dart';

abstract class SelectionDialog<T> {

  final Set<T> options;
  final ListSelectorType selectorType;
  final Function(T, bool?) onChanged;
  final VoidCallback onClose;
  final bool Function(dynamic) isSelectedFn;

  const SelectionDialog({
    required this.options,
    required this.selectorType,
    required this.onChanged,
    required this.onClose,
    required this.isSelectedFn,
  });
  

  Future show(BuildContext context);
}