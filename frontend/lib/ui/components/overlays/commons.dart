
import 'package:flutter/material.dart';

Widget makeNotificationWidget(Widget child) {
  return Material(
    color: Colors.transparent,
    child: Container(
      width: 400,
      height: 400,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    ),
  );
}