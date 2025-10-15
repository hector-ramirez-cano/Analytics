import 'package:flutter/material.dart';

enum OptionDialogType {
  cancelDelete,
  cancelAccept,
  discardSave,
}

class OptionDialog{

  final OptionDialogType dialogType;
  final Widget title;
  final Widget confirmMessage;

  final Function()? onCancel;
  final Function()? onDelete;
  final Function()? onAccept;
  final Function()? onDiscard;
  final Function()? onSave;

  const OptionDialog({
    required this.title,
    required this.confirmMessage,
    required this.dialogType,

    this.onCancel,
    this.onDelete,
    this.onAccept,
    this.onDiscard,
    this.onSave,
  });

  void dismiss(BuildContext context) {
    if (context.mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Widget _makeOptionButtons(BuildContext context) {
    String leftBtnLabel = "";
    String rightBtnLabel = "";
    Function()? leftAction;
    Function()? rightAction;

    switch (dialogType) {
      
      case OptionDialogType.cancelDelete:
        leftBtnLabel = "Cancelar";
        rightBtnLabel = "Eliminar";
        leftAction  = () { dismiss(context);  if (onCancel != null) { onCancel!(); }};
        rightAction = () { dismiss(context);  if (onDelete != null) { onDelete!(); }};
        
      case OptionDialogType.cancelAccept:
        leftBtnLabel = "Cancelar";
        rightBtnLabel = "Aceptar";
        leftAction  = () { dismiss(context);  if (onCancel != null) { onCancel!(); }};
        rightAction = () { dismiss(context);  if (onAccept != null) { onAccept!(); }};

      case OptionDialogType.discardSave:
        leftBtnLabel = "Descartar";
        rightBtnLabel = "Guardar";
        leftAction  = () { dismiss(context);  if (onDiscard != null) { onDiscard!(); }};
        rightAction = () { dismiss(context);  if (onSave    != null) { onSave   !(); }};
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

  Future show(BuildContext context) {
    final dialog = Container(
      color: const Color.fromRGBO(100, 100, 100, 0.5),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(50, 50, 50, 150),
        child: Center(
          child: _makeOptionButtons(context),
        ),
      ),
    );

    return showDialog(context: context, builder: (context) => dialog);
  }
  
}