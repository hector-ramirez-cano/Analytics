import 'package:flutter/material.dart';

class BadgeButton extends StatelessWidget {
  final Color backgroundColor;
  final String text;
  final VoidCallback? onPressed;
  final TextStyle? textStyle;

  const BadgeButton({
    super.key,
    required this.backgroundColor,
    required this.text,
    this.onPressed,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return 
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            minimumSize: Size.zero, // removes default min constraints
            tapTargetSize: MaterialTapTargetSize.shrinkWrap, // keeps it small
          ),
          onPressed: onPressed,
          child: Text(text, style: textStyle,),
    );
  }
}