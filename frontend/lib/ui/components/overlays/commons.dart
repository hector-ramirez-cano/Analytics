
import 'package:flutter/material.dart';

Widget makeNotificationWidget(BuildContext context, Widget child, {bool shrinkWrap = false}) {
  return Material(
    color: Colors.transparent,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
        minHeight: 200,
        maxWidth: 400,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 6, 6, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 16,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );

}