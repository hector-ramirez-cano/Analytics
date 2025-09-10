import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_analytics/ui/components/universal_detector.dart';

class EditTextField extends StatelessWidget {
  final String initialText;
  final bool showEditIcon;
  final Color backgroundColor;
  final bool enabled;
  final Function(String)? onContentEdit;
  final VoidCallback? onEditToggle;
  final VoidCallback? onEditingComplete;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final List<FilteringTextInputFormatter>? formatters;

  
  const EditTextField({
    super.key,
    required this.enabled,
    required this.initialText,

    this.onContentEdit,
    this.controller,
    this.keyboardType,
    this.formatters,
    this.onEditToggle,
    this.onEditingComplete,
    this.backgroundColor = Colors.transparent,
    this.showEditIcon = false,
  });

  Widget makeTrailingInput() {
    return TextField(
      enabled: enabled,
      autocorrect: false,
      keyboardType: keyboardType, 
      controller: controller ?? TextEditingController(text: initialText),
      inputFormatters: formatters,
      decoration: InputDecoration(
        filled: true,
        fillColor: backgroundColor,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      onChanged: onContentEdit,
      onEditingComplete: onEditingComplete,
    );
  }

  Widget _makeTrailingIcon() {
    return 
      UniversalDetector(
        setCursor: () => SystemMouseCursors.click,
        onTapUp: (_) => onEditToggle != null ? onEditToggle!() : () => {},
        child: Icon(
              Icons.edit,
              size: 20,
              color: Colors.black54,
            )
      ); 
  }

  Widget makeTrailing(Widget child) {
    return SizedBox(
      width: 220, // adjust to accommodate icon
      child: Row(
        
        children: [
          Expanded(
            child: child,
          ),
          const SizedBox(width: 4),
          showEditIcon ? 
            _makeTrailingIcon()
            : SizedBox.shrink()
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    var input = makeTrailingInput();

    return makeTrailing(input);
  }

}
