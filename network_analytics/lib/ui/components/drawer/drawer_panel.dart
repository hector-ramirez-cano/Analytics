import 'package:flutter/material.dart';

class DrawerPanel extends StatelessWidget {
  final double width;
  final bool isVisible;
  final Animation<double> fadeAnimation;
  final String label;

  const DrawerPanel({
    super.key,
    required this.width,
    required this.isVisible,
    required this.fadeAnimation,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: isVisible
          ? FadeTransition(
              opacity: fadeAnimation,
              child: Container(
                color: Colors.grey.shade300,
                padding: const EdgeInsets.all(16),
                alignment: Alignment.topLeft,
                child: Text(
                  '$label Panel',
                  style: const TextStyle(fontSize: 18, color: Colors.black87),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  
}
