import 'package:flutter/material.dart';

class EmptyEditView extends StatelessWidget{
  const EmptyEditView({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min, // keeps the column as small as possible
          children: const [
            Icon(Icons.category_outlined, size: 128, color: Colors.blueGrey,),
            SizedBox(height: 12), // spacing between icon and text
            Text("Selecciona un dispositivo, enlace o grupo para editarlo"),
          ],
        ),
      ),
    );
  }
}