
import 'package:flutter/material.dart';

Widget makeNotificationWidget(BuildContext context, Widget child) {
  return Material(
    color: Colors.transparent,
    child: Container(
      width: 400,
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.fromLTRB(0, 6, 6, 6),
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