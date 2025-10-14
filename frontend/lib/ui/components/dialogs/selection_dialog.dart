import 'package:flutter/material.dart';
import 'package:network_analytics/ui/components/list_selector.dart';


Icon? noIcon(dynamic _) => null;
abstract class SelectionDialog<T> {

  final Set<T> options;
  final ListSelectorType selectorType;
  final Function(T, bool?) onChanged;
  final VoidCallback onClose;
  final bool Function(dynamic) isSelectedFn;
  final void Function(bool)? onTristateToggle;
  final Icon? Function(dynamic) leadingIconFn;

  const SelectionDialog({
    required this.options,
    required this.selectorType,
    required this.onChanged,
    required this.onClose,
    required this.isSelectedFn,
    required this.onTristateToggle,

    this.leadingIconFn = noIcon,
  });
  

  Future show(BuildContext context);
}