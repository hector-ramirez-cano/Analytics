import 'package:flutter/material.dart';

class EmptyDialog<T> {
  static Map defaultOnClose() => {};

  final Widget child;
  final Function() onClose;

  const EmptyDialog({
    required this.child,

    this.onClose = defaultOnClose,
  });

  Widget _makeCloseButton(BuildContext context) {
    onCloseWrapper() {
      if(context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        onClose();
      }
    }

    return Row(
      children: [
        Spacer(),
        IconButton(
          onPressed: onCloseWrapper,
          icon: Icon(Icons.close, color: Colors.black),
        ),
      ],
    );
  }


  Future show(BuildContext context) {
    final dialog = Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            children: [
              _makeCloseButton(context),
              child,
            ],
          ),
        ),
      ),
    );

    return showDialog(context: context, builder: (context) => dialog);
  }
}