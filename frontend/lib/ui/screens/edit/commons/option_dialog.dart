import 'package:flutter/material.dart';

enum OptionDialogType {
  cancelDelete,
  cancelAccept
}

class OptionDialog extends StatelessWidget{

  final OptionDialogType dialogType;
  final Widget title;
  final Widget confirmMessage;

  final Function()? onCancel;
  final Function()? onDelete;
  final Function()? onAccept;

  const OptionDialog({
    super.key,
    required this.title,
    required this.confirmMessage,
    required this.dialogType,

    this.onCancel,
    this.onDelete,
    this.onAccept,
  });

  Widget _makeOptionButtons() {
    String leftBtnLabel = "";
    String rightBtnLabel = "";
    Function()? leftAction;
    Function()? rightAction;

    switch (dialogType) {
      
      case OptionDialogType.cancelDelete:
        leftBtnLabel = "Cancelar";
        rightBtnLabel = "Eliminar";
        leftAction = onCancel;
        rightAction = onDelete;
        
      case OptionDialogType.cancelAccept:
        leftBtnLabel = "Cancelar";
        rightBtnLabel = "Aceptar";
        leftAction = onCancel;
        rightAction = onAccept;
    }

    return AlertDialog.adaptive(
      title: title,
      content: confirmMessage,
      actions: [
        TextButton(onPressed: leftAction , child: Text(leftBtnLabel)),
        TextButton(onPressed: rightAction, child: Text(rightBtnLabel)),
      ],
    );
  }



  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromRGBO(100, 100, 100, 0.5),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(50, 50, 50, 150),
        child: Center(
          child: _makeOptionButtons(),
        ),
      ),
    );
  }
  
}